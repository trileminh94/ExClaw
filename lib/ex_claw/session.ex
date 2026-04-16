defmodule ExClaw.Session do
  @moduledoc """
  Agent Actor — thin lifecycle wrapper around the Pipeline Executor.

  Responsibilities:
  - Hydrate message history from the store on startup
  - Build RunInput from application config
  - Delegate the full Think-Act-Observe loop to Pipeline.Executor
  - Handle human approval for dangerous tools (pause/resume)

  States:
  - :idle              — waiting for user input
  - :thinking          — pipeline running (LLM + tools)
  - :awaiting_approval — dangerous tool detected, waiting for human go-ahead
  """
  use GenServer
  require Logger

  alias ExClaw.Pipeline.{Executor, RunInput}
  alias ExClaw.StoreSQLite.{Session, Message}

  defstruct [
    :session_id,
    :agent_id,
    :user_id,
    :tenant_id,
    :run_input,
    :pipeline_state,   # RunState.t() held while :awaiting_approval
    messages: [],
    status: :idle,
    caller: nil
  ]

  # -- Client API --

  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)

    GenServer.start_link(__MODULE__, opts,
      name: {:via, Registry, {ExClaw.Registry, {:session, session_id}}}
    )
  end

  def send_message(session_id, text) do
    via = {:via, Registry, {ExClaw.Registry, {:session, session_id}}}
    GenServer.call(via, {:user_input, text}, 120_000)
  end

  @doc """
  Like send_message/2 but streams LLM chunks to `stream_pid` via StreamChunk messages.
  The session temporarily sets stream_pid on its run_input for this turn only.
  """
  def send_message_stream(session_id, text, stream_pid) do
    via = {:via, Registry, {ExClaw.Registry, {:session, session_id}}}
    GenServer.call(via, {:user_input, text, stream_pid}, 120_000)
  end

  def approve_tools(session_id, decision) do
    via = {:via, Registry, {ExClaw.Registry, {:session, session_id}}}
    GenServer.cast(via, {:approval, decision})
  end

  def get_status(session_id) do
    via = {:via, Registry, {ExClaw.Registry, {:session, session_id}}}
    GenServer.call(via, :get_status)
  end

  # -- Server Callbacks --

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    agent_id = Keyword.get(opts, :agent_id)
    user_id = Keyword.get(opts, :user_id)
    tenant_id = Keyword.get(opts, :tenant_id)

    {:ok, messages} = Session.hydrate_messages(session_id, 20)

    run_input = build_run_input(session_id, agent_id, user_id, tenant_id)

    state = %__MODULE__{
      session_id: session_id,
      agent_id: agent_id,
      user_id: user_id,
      tenant_id: tenant_id,
      run_input: run_input,
      messages: Enum.map(messages, &to_llm_message/1),
      status: :idle
    }

    Logger.info("[Session #{session_id}] Started, loaded #{length(messages)} messages")
    {:ok, state}
  end

  @impl true
  def handle_call({:user_input, text}, from, %{status: :idle} = state) do
    handle_user_input(text, nil, from, state)
  end

  def handle_call({:user_input, text, stream_pid}, from, %{status: :idle} = state) do
    handle_user_input(text, stream_pid, from, state)
  end

  def handle_call({:user_input, _text}, _from, state) do
    {:reply, {:error, {:busy, state.status}}, state}
  end

  def handle_call({:user_input, _text, _stream_pid}, _from, state) do
    {:reply, {:error, {:busy, state.status}}, state}
  end

  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_cast({:approval, :granted}, %{status: :awaiting_approval, pipeline_state: ps} = state) do
    send(self(), {:resume_pipeline, ps})
    {:noreply, %{state | status: :thinking, pipeline_state: nil}}
  end

  def handle_cast({:approval, :denied}, %{status: :awaiting_approval} = state) do
    denial = "Execution of the requested tool(s) was denied."

    {:ok, _} =
      Message.append_message(%{
        session_id: state.session_id,
        agent_id: state.agent_id,
        user_id: state.user_id,
        tenant_id: state.tenant_id,
        role: "assistant",
        content: denial
      })

    reply_to_caller(state.caller, {:ok, denial})
    {:noreply, %{state | status: :idle, pipeline_state: nil, caller: nil}}
  end

  @impl true
  def handle_info({:run_pipeline, stream_pid}, state) do
    run_input = %{state.run_input | stream_pid: stream_pid}
    case Executor.run(run_input, state.messages) do
      {:ok, content, updated_messages} ->
        reply_to_caller(state.caller, {:ok, content})
        {:noreply, %{state | messages: updated_messages, status: :idle, caller: nil}}

      {:needs_approval, pipeline_state, _calls} ->
        {:noreply, %{state | status: :awaiting_approval, pipeline_state: pipeline_state}}

      {:error, reason} ->
        Logger.error("[Session #{state.session_id}] Pipeline error: #{inspect(reason)}")
        reply_to_caller(state.caller, {:error, reason})
        {:noreply, %{state | status: :idle, caller: nil}}
    end
  end

  def handle_info({:resume_pipeline, pipeline_state}, state) do
    case Executor.resume(pipeline_state) do
      {:ok, content, updated_messages} ->
        reply_to_caller(state.caller, {:ok, content})
        {:noreply, %{state | messages: updated_messages, status: :idle, caller: nil}}

      {:needs_approval, new_ps, _calls} ->
        {:noreply, %{state | status: :awaiting_approval, pipeline_state: new_ps}}

      {:error, reason} ->
        Logger.error("[Session #{state.session_id}] Pipeline resume error: #{inspect(reason)}")
        reply_to_caller(state.caller, {:error, reason})
        {:noreply, %{state | status: :idle, caller: nil}}
    end
  end

  def handle_info({ref, _result}, state) when is_reference(ref), do: {:noreply, state}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state), do: {:noreply, state}

  defp handle_user_input(text, stream_pid, from, state) do
    {:ok, _} =
      Message.append_message(%{
        session_id: state.session_id,
        agent_id: state.agent_id,
        user_id: state.user_id,
        tenant_id: state.tenant_id,
        role: "user",
        content: text
      })

    messages = state.messages ++ [%{role: "user", content: text}]
    send(self(), {:run_pipeline, stream_pid})

    {:noreply, %{state | messages: messages, status: :thinking, caller: from}}
  end

  # -- Private --

  defp build_run_input(session_id, agent_id, user_id, tenant_id) do
    provider_module = resolve_provider_module()
    api_key = Application.get_env(:ex_claw, :api_key, "")
    model = Application.get_env(:ex_claw, :model, provider_module.default_model())

    %RunInput{
      session_id: session_id,
      agent_id: agent_id,
      user_id: user_id,
      tenant_id: tenant_id,
      provider_module: provider_module,
      provider_config: %{api_key: api_key, model: model},
      pool_name: ExClaw.LLM.Pool,
      max_iterations: 20
    }
  end

  defp resolve_provider_module do
    case Application.get_env(:ex_claw, :llm_provider, :anthropic) do
      :anthropic -> ExClaw.LLM.Providers.Anthropic
      :openai -> ExClaw.LLM.Providers.OpenAI
      :dashscope -> ExClaw.LLM.Providers.DashScope
      mod when is_atom(mod) -> mod
    end
  end

  defp to_llm_message(%{role: role, content: content, tool_calls: tc, tool_results: tr}) do
    base = %{role: role, content: content}
    base = if tc, do: Map.put(base, :tool_calls, tc), else: base
    if tr, do: Map.put(base, :tool_results, tr), else: base
  end

  defp to_llm_message(m) when is_map(m), do: m

  defp reply_to_caller(nil, _msg), do: :ok
  defp reply_to_caller(from, msg), do: GenServer.reply(from, msg)
end
