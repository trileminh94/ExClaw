defmodule ExClaw.Pipeline.Stages.FinalizeStage do
  @moduledoc """
  Stage 7: Post-loop finalization.

  - Flushes any remaining pending_db_messages (e.g. final assistant message)
  - Updates session status in the DB to 'idle'
  - Emits basic metrics (iteration count, token usage) to Logger

  Phase 10 will add OTel span emission and cost calculation here.
  """
  @behaviour ExClaw.Pipeline.Stage

  require Logger
  alias ExClaw.Pipeline.RunState
  alias ExClaw.StoreSQLite.{Message, Session}

  @impl true
  def execute(%RunState{run_input: input} = state) do
    # Flush the final text response to DB
    state =
      if state.final_content do
        final_msg = %{
          session_id: input.session_id,
          agent_id: input.agent_id,
          user_id: input.user_id,
          tenant_id: input.tenant_id,
          role: "assistant",
          content: state.final_content
        }

        case Message.append_message(final_msg) do
          {:ok, _} -> :ok
          {:error, err} -> Logger.warning("[FinalizeStage] Failed to persist final message: #{inspect(err)}")
        end

        # Clear pending if it matches the final content (avoid double-write)
        %{state | pending_db_messages: []}
      else
        state
      end

    # Flush any remaining pending messages
    state =
      if state.pending_db_messages != [] do
        Enum.each(state.pending_db_messages, fn msg ->
          attrs = %{
            session_id: input.session_id,
            agent_id: input.agent_id,
            user_id: input.user_id,
            tenant_id: input.tenant_id,
            role: to_string(msg[:role] || msg["role"]),
            content: msg[:content] || msg["content"],
            tool_calls: msg[:tool_calls] || msg["tool_calls"]
          }
          Message.append_message(attrs)
        end)

        %{state | pending_db_messages: []}
      else
        state
      end

    # Update session status back to idle
    Session.update_session(input.session_id, %{status: "idle"})

    usage = state.last_response && state.last_response.usage

    Logger.info(
      "[FinalizeStage] session=#{input.session_id} iterations=#{state.iteration}" <>
        if(usage, do: " tokens=#{usage.prompt_tokens}+#{usage.completion_tokens}", else: "")
    )

    {:ok, state}
  end
end
