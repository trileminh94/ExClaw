defmodule ExClaw.Pipeline.Stage do
  @moduledoc """
  Behaviour for a pipeline stage.

  Each stage receives a RunState and returns one of:
  - `{:ok, RunState.t()}` — continue to next stage / next iteration
  - `{:break_loop, RunState.t()}` — exit the iteration loop and finalize
  - `{:needs_approval, RunState.t(), tool_calls}` — pause for human approval
  - `{:abort_run, reason}` — fatal error, stop immediately
  """

  alias ExClaw.Pipeline.RunState

  @callback execute(RunState.t()) ::
              {:ok, RunState.t()}
              | {:break_loop, RunState.t()}
              | {:needs_approval, RunState.t(), tool_calls :: [map()]}
              | {:abort_run, reason :: term()}
end
