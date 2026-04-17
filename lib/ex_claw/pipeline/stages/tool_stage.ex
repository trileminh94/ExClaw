defmodule ExClaw.Pipeline.Stages.ToolStage do
  @moduledoc """
  Stage 4: Execute pending tool calls via Tool.Executor.

  Safe tools are executed concurrently (Task.async_stream inside Executor).
  Dangerous tools pause execution and return {:needs_approval, state, calls}.
  On resume (state.approved = true), all pending tools including dangerous ones run.

  Uses Tool.Registry to check which tools are flagged dangerous rather than
  the old static config list, falling back to config for backward compat.
  """
  @behaviour ExClaw.Pipeline.Stage

  require Logger
  alias ExClaw.Pipeline.RunState
  alias ExClaw.Tool.{Executor, Registry}

  @impl true
  def execute(%RunState{pending_tool_calls: []} = state) do
    {:ok, state}
  end

  def execute(%RunState{pending_tool_calls: calls, approved: approved} = state) do
    dangerous_calls = Enum.filter(calls, &dangerous?/1)

    if dangerous_calls != [] and not approved do
      Logger.info("[ToolStage] Pausing for approval — dangerous tools: " <>
        inspect(Enum.map(dangerous_calls, & &1["name"])))
      {:needs_approval, state, dangerous_calls}
    else
      context = build_context(state.run_input)
      results = Executor.execute_all(calls, context)

      # Convert Executor result format to RunState tool_results format
      formatted =
        Enum.zip(calls, results)
        |> Enum.map(fn {call, res} ->
          %{
            tool: call["name"],
            id:   call["id"],
            status: if(String.starts_with?(res["content"] || "", "Error:"), do: :error, else: :ok),
            output: res["content"]
          }
        end)

      {:ok,
       %{state
         | tool_results: formatted,
           pending_tool_calls: [],
           approved: false}}
    end
  end

  # -- Private --

  defp dangerous?(call) do
    name = call["name"]
    # Check registry first (authoritative); fall back to config list
    case Registry.lookup(name) do
      {:ok, {meta, _}} -> meta.dangerous
      {:error, _} ->
        dangerous_list = Application.get_env(:ex_claw, :dangerous_tools, [])
        name in dangerous_list
    end
  end

  defp build_context(%{user_id: uid, agent_id: aid, tenant_id: tid}) do
    %{user_id: uid, agent_id: aid, tenant_id: tid}
  end

  defp build_context(_), do: %{}
end
