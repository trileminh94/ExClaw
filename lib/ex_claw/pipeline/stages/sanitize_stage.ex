defmodule ExClaw.Pipeline.Stages.SanitizeStage do
  @moduledoc """
  Stage 8: Output sanitization.

  Cleans the final_content before returning to the caller.

  Phase 2: minimal — just trims whitespace.
  Phase 7 (Security Hardening) will add:
  - Credential pattern scrubbing (API keys, tokens, passwords)
  - Prompt injection artifact removal
  - Tenant-specific redaction rules
  """
  @behaviour ExClaw.Pipeline.Stage

  alias ExClaw.Pipeline.RunState

  @impl true
  def execute(%RunState{final_content: nil} = state) do
    {:ok, %{state | final_content: ""}}
  end

  def execute(%RunState{final_content: content} = state) when is_binary(content) do
    {:ok, %{state | final_content: String.trim(content)}}
  end

  def execute(%RunState{} = state) do
    {:ok, state}
  end
end
