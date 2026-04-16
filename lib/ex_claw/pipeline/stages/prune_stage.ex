defmodule ExClaw.Pipeline.Stages.PruneStage do
  @moduledoc """
  Stage 3: Context-window pruning.

  Prevents unbounded message growth by trimming old messages when the
  conversation history exceeds a soft threshold.

  Phase 2 implementation: simple message-count heuristic.
  Phase 5 will replace this with token-accurate counting and mid-loop compaction.

  Strategy:
  - Keep the first message (establishes task context)
  - Keep the last N messages (recent context)
  - Drop oldest middle messages when total > soft_limit
  """
  @behaviour ExClaw.Pipeline.Stage

  alias ExClaw.Pipeline.RunState

  @soft_limit 40   # messages before pruning
  @keep_recent 20  # always keep last N messages

  @impl true
  def execute(%RunState{messages: messages} = state) when length(messages) <= @soft_limit do
    {:ok, state}
  end

  def execute(%RunState{messages: messages} = state) do
    pruned = prune(messages, @keep_recent)
    {:ok, %{state | messages: pruned}}
  end

  # -- Private --

  defp prune([first | rest], keep_recent) do
    total = length(rest) + 1
    drop_count = total - keep_recent - 1  # -1 for first message

    if drop_count > 0 do
      trimmed = Enum.drop(rest, drop_count)
      [first | trimmed]
    else
      [first | rest]
    end
  end

  defp prune([], _), do: []
end
