defmodule ExClaw.Pipeline.Stages.CheckpointStage do
  @moduledoc """
  Stage 6: Write-behind cache flush.

  Persists pending_db_messages to the MessageStore atomically after each iteration.
  This is the write-behind pattern: messages are held in memory during the pipeline
  loop and flushed to DB at the checkpoint.

  Phase 4 will add transaction wrapping and failure recovery.
  """
  @behaviour ExClaw.Pipeline.Stage

  require Logger
  alias ExClaw.Pipeline.RunState
  alias ExClaw.StoreSQLite.Message, as: MessageStore

  @impl true
  def execute(%RunState{pending_db_messages: []} = state) do
    {:ok, state}
  end

  def execute(%RunState{pending_db_messages: msgs, run_input: input} = state) do
    Enum.each(msgs, fn msg ->
      attrs = %{
        session_id: input.session_id,
        agent_id: input.agent_id,
        user_id: input.user_id,
        tenant_id: input.tenant_id,
        role: to_string(msg[:role] || msg["role"]),
        content: msg[:content] || msg["content"],
        tool_calls: msg[:tool_calls] || msg["tool_calls"],
        tool_results: msg[:tool_results] || msg["tool_results"]
      }

      case MessageStore.append_message(attrs) do
        {:ok, _} -> :ok
        {:error, err} -> Logger.warning("[CheckpointStage] Failed to persist message: #{inspect(err)}")
      end
    end)

    {:ok, %{state | pending_db_messages: []}}
  end
end
