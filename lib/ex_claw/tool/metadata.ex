defmodule ExClaw.Tool.Metadata do
  @moduledoc """
  Compile-time metadata for a registered tool.

  Fields:
  - `name`          — unique tool name string (e.g. "bash", "read_file")
  - `group`         — atom grouping (:fs | :runtime | :web | :memory | :delegation | :teams)
  - `description`   — human-readable description (also used in LLM tool spec)
  - `parameters`    — JSON Schema map for tool input (Anthropic tool_use format)
  - `dangerous`     — true if the tool requires human approval before execution
  - `rate_limit`    — max calls per minute per user (nil = unlimited)
  - `deny_patterns` — list of compiled regex patterns to reject in tool input
  - `sandbox`       — true to run inside Docker sandbox (Phase 7)
  """

  @enforce_keys [:name, :group, :description, :parameters]
  defstruct [
    :name,
    :group,
    :description,
    :parameters,
    dangerous: false,
    rate_limit: nil,
    deny_patterns: [],
    sandbox: false
  ]

  @type t :: %__MODULE__{
    name:          String.t(),
    group:         atom(),
    description:   String.t(),
    parameters:    map(),
    dangerous:     boolean(),
    rate_limit:    non_neg_integer() | nil,
    deny_patterns: [Regex.t()],
    sandbox:       boolean()
  }

  @doc "Convert metadata to the Anthropic tool_use definition format."
  @spec to_llm_definition(t()) :: map()
  def to_llm_definition(%__MODULE__{} = m) do
    %{
      "name"        => m.name,
      "description" => m.description,
      "input_schema" => m.parameters
    }
  end
end
