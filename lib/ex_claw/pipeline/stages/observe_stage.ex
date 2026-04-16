defmodule ExClaw.Pipeline.Stages.ObserveStage do
  @moduledoc """
  Stage 5: Convert tool results into LLM-formatted messages.

  Appends tool result messages to state.messages so the next ThinkStage
  iteration can see what happened.
  Also queues them for DB flush in CheckpointStage.
  """
  @behaviour ExClaw.Pipeline.Stage

  alias ExClaw.Pipeline.RunState

  @impl true
  def execute(%RunState{tool_results: []} = state) do
    {:ok, state}
  end

  def execute(%RunState{tool_results: results} = state) do
    tool_messages =
      Enum.map(results, fn r ->
        %{
          role: "tool",
          content: r.output,
          name: r.tool,
          tool_use_id: r.id
        }
      end)

    {:ok,
     %{state
       | messages: state.messages ++ tool_messages,
         pending_db_messages: state.pending_db_messages ++ tool_messages,
         tool_results: []}}
  end
end
