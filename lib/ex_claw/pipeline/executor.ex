defmodule ExClaw.Pipeline.Executor do
  @moduledoc """
  Orchestrates the 8-stage pipeline loop.

  Entry point: `run/2` — starts a new pipeline run.
  Resume point: `resume/1` — continues after user approval for dangerous tools.

  Flow:
    1. ContextStage (once, before loop)
    2. Loop up to max_iterations:
       ThinkStage → PruneStage → ToolStage → ObserveStage → CheckpointStage
       - {:break_loop, state} exits the loop
       - {:needs_approval, state, calls} pauses and returns to caller
       - {:abort_run, reason} returns error immediately
    3. FinalizeStage → SanitizeStage (once, after loop)

  Returns:
    {:ok, content, updated_messages}
    {:needs_approval, pipeline_state, dangerous_tool_calls}
    {:error, reason}
  """

  require Logger

  alias ExClaw.Pipeline.{RunInput, RunState}
  alias ExClaw.Pipeline.Stages.{
    ContextStage,
    ThinkStage,
    PruneStage,
    ToolStage,
    ObserveStage,
    CheckpointStage,
    FinalizeStage,
    SanitizeStage
  }

  @loop_stages [ThinkStage, PruneStage, ToolStage, ObserveStage, CheckpointStage]

  @doc """
  Start a new pipeline run.

  `run_input` carries immutable configuration (provider, session IDs, etc.).
  `messages` is the current conversation history (already includes the latest user message).
  """
  @spec run(RunInput.t(), messages :: [map()]) ::
          {:ok, String.t(), [map()]}
          | {:needs_approval, RunState.t(), [map()]}
          | {:error, term()}
  def run(%RunInput{} = run_input, messages) do
    state = %RunState{run_input: run_input, messages: messages}

    case ContextStage.execute(state) do
      {:ok, state} -> loop(state)
      {:abort_run, reason} -> {:error, reason}
    end
  end

  @doc """
  Resume a pipeline run after the user approves dangerous tool execution.
  Re-enters at ToolStage with `state.approved = true`.
  """
  @spec resume(RunState.t()) ::
          {:ok, String.t(), [map()]}
          | {:needs_approval, RunState.t(), [map()]}
          | {:error, term()}
  def resume(%RunState{} = state) do
    state = %{state | approved: true}
    resume_stages = [ToolStage, ObserveStage, CheckpointStage]

    case run_stages(resume_stages, state) do
      {:continue, state} -> loop(state)
      {:break_loop, state} -> finalize(state)
      {:needs_approval, state, calls} -> {:needs_approval, state, calls}
      {:abort_run, reason} -> {:error, reason}
    end
  end

  # -- Private --

  defp loop(%RunState{iteration: n, run_input: %{max_iterations: max}} = state) when n >= max do
    Logger.warning("[Executor] max_iterations=#{max} reached for session=#{state.run_input.session_id}")
    finalize(%{state | final_content: state.final_content || "(reached iteration limit)"})
  end

  defp loop(%RunState{} = state) do
    case run_stages(@loop_stages, state) do
      {:continue, state} ->
        loop(%{state | iteration: state.iteration + 1})

      {:break_loop, state} ->
        finalize(state)

      {:needs_approval, state, calls} ->
        {:needs_approval, state, calls}

      {:abort_run, reason} ->
        {:error, reason}
    end
  end

  defp finalize(%RunState{} = state) do
    with {:ok, state} <- FinalizeStage.execute(state),
         {:ok, state} <- SanitizeStage.execute(state) do
      {:ok, state.final_content, state.messages}
    else
      {:abort_run, reason} -> {:error, reason}
    end
  end

  # Run a list of stages sequentially. Returns the first non-{:ok, state} result,
  # or {:continue, state} if all stages returned {:ok, state}.
  defp run_stages([], state), do: {:continue, state}

  defp run_stages([stage | rest], state) do
    case stage.execute(state) do
      {:ok, state} ->
        run_stages(rest, state)

      {:break_loop, _} = result ->
        result

      {:needs_approval, _, _} = result ->
        result

      {:abort_run, _} = result ->
        result
    end
  end
end
