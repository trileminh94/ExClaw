defmodule ExClaw.Pipeline.Stages.ThinkStage do
  @moduledoc """
  Stage 2: Call the LLM provider and process the response.

  Checks out a client from the provider pool, calls chat/2 (or chat_stream/3
  when stream_pid is set), and interprets the response:

  - Text-only response  → {:break_loop, state with final_content set}
  - Tool-call response  → {:ok, state with pending_tool_calls set}
  - Empty response      → inject an iteration-nudge message and continue
  - Error               → {:abort_run, reason}
  """
  @behaviour ExClaw.Pipeline.Stage

  require Logger
  alias ExClaw.Pipeline.RunState
  alias ExClaw.LLM.{Request, Response}

  @max_tokens 4096

  @impl true
  def execute(%RunState{run_input: input} = state) do
    request = %Request{
      model: Map.get(input.provider_config, :model) || input.provider_module.default_model(),
      system: state.system_prompt,
      messages: state.messages,
      tools: state.tool_definitions,
      max_tokens: @max_tokens
    }

    result =
      NimblePool.checkout!(input.pool_name, :checkout, fn _from, client ->
        resp =
          if input.stream_pid do
            input.provider_module.chat_stream(client, request, input.stream_pid)
          else
            input.provider_module.chat(client, request)
          end

        {resp, client}
      end)

    handle_response(result, state)
  end

  # -- Private --

  defp handle_response({:ok, %Response{} = response}, state) do
    state = %{state | last_response: response}

    cond do
      Response.has_tool_calls?(response) ->
        Logger.debug("[ThinkStage] iter=#{state.iteration} → tool calls: #{length(response.tool_calls)}")
        # Queue LLM's assistant turn (with tool_calls) for DB flush in CheckpointStage
        assistant_msg = %{role: "assistant", content: response.content, tool_calls: response.tool_calls}
        {:ok,
         %{state
           | messages: state.messages ++ [assistant_msg],
             pending_tool_calls: response.tool_calls,
             pending_db_messages: state.pending_db_messages ++ [assistant_msg]}}

      Response.text_only?(response) ->
        Logger.debug("[ThinkStage] iter=#{state.iteration} → text response, breaking loop")
        {:break_loop, %{state | final_content: response.content}}

      true ->
        # Empty response — nudge and continue
        Logger.warning("[ThinkStage] iter=#{state.iteration} → empty response, nudging")
        nudge = %{role: "user", content: "Please continue."}
        {:ok, %{state | messages: state.messages ++ [nudge]}}
    end
  end

  defp handle_response({:error, reason}, _state) do
    Logger.error("[ThinkStage] Provider error: #{inspect(reason)}")
    {:abort_run, reason}
  end
end
