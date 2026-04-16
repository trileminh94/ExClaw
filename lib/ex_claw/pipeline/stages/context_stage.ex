defmodule ExClaw.Pipeline.Stages.ContextStage do
  @moduledoc """
  Stage 1: Build the system prompt and inject tool definitions.

  Sources (in priority order):
  1. Agent context files via Bootstrap.FileRouter (SOUL.md, IDENTITY.md, etc.)
  2. User context files (USER.md)
  3. Default system prompt if no context files found

  Also loads tool definitions from Tool.Runner (Phase 4 will upgrade to Tool.Registry).
  """
  @behaviour ExClaw.Pipeline.Stage

  alias ExClaw.Pipeline.RunState
  alias ExClaw.Bootstrap.FileRouter

  @impl true
  def execute(%RunState{run_input: input} = state) do
    system_prompt = build_system_prompt(input.agent_id, input.user_id)
    tools = load_tools()

    {:ok, %{state | system_prompt: system_prompt, tool_definitions: tools}}
  end

  # -- Private --

  defp build_system_prompt(agent_id, user_id) do
    parts = []

    # SOUL.md — agent personality/identity
    parts =
      case FileRouter.get_file(agent_id, "SOUL.md") do
        {:ok, content} -> [content | parts]
        _ -> parts
      end

    # USER.md — per-user context
    parts =
      case FileRouter.get_user_file(agent_id, user_id, "USER.md") do
        {:ok, content} -> [content | parts]
        _ -> parts
      end

    case parts do
      [] -> default_system_prompt()
      _ -> Enum.reverse(parts) |> Enum.join("\n\n---\n\n")
    end
  end

  defp default_system_prompt do
    "You are a helpful AI assistant. You have access to tools to help you complete tasks."
  end

  defp load_tools do
    ExClaw.Tool.Runner.tool_definitions()
  end
end
