defmodule ExClaw.Pipeline.Stages.ToolStage do
  @moduledoc """
  Stage 4: Execute pending tool calls.

  Safe tools are executed immediately.
  Dangerous tools pause execution and return {:needs_approval, state, calls}.
  On resume (state.approved = true), executes all pending tools including dangerous ones.

  Execution is sequential in Phase 2; Phase 4 will parallelize safe tools.
  """
  @behaviour ExClaw.Pipeline.Stage

  require Logger
  alias ExClaw.Pipeline.RunState

  @impl true
  def execute(%RunState{pending_tool_calls: []} = state) do
    {:ok, state}
  end

  def execute(%RunState{pending_tool_calls: calls, approved: approved} = state) do
    dangerous = Application.get_env(:ex_claw, :dangerous_tools, [])
    dangerous_calls = Enum.filter(calls, fn tc -> tc["name"] in dangerous end)

    if dangerous_calls != [] and not approved do
      Logger.info("[ToolStage] Pausing for approval — dangerous tools: #{inspect(Enum.map(dangerous_calls, & &1["name"]))}")
      {:needs_approval, state, dangerous_calls}
    else
      results = execute_all(calls)

      {:ok,
       %{state
         | tool_results: results,
           pending_tool_calls: [],
           approved: false}}
    end
  end

  # -- Private --

  defp execute_all(tool_calls) do
    Enum.map(tool_calls, fn %{"name" => name, "input" => input} = tc ->
      Logger.debug("[ToolStage] executing tool=#{name}")

      result =
        case ExClaw.Tool.Runner.execute(name, input) do
          {:ok, output} -> %{tool: name, id: tc["id"], status: :ok, output: output}
          {:error, reason} -> %{tool: name, id: tc["id"], status: :error, output: inspect(reason)}
        end

      result
    end)
  end
end
