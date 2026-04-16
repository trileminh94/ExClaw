defmodule ExClaw.LLM.Response do
  @moduledoc "Canonical LLM response returned by any provider."

  @type usage :: %{prompt_tokens: non_neg_integer(), completion_tokens: non_neg_integer()}

  @type t :: %__MODULE__{
          content: String.t() | nil,
          thinking: String.t() | nil,
          tool_calls: [map()] | nil,
          usage: usage(),
          model: String.t() | nil,
          stop_reason: String.t() | nil
        }

  defstruct [
    :content,
    :thinking,
    :tool_calls,
    :model,
    :stop_reason,
    usage: %{prompt_tokens: 0, completion_tokens: 0}
  ]

  @doc "Returns true when the response contains at least one tool call."
  def has_tool_calls?(%__MODULE__{tool_calls: tc}), do: is_list(tc) and tc != []

  @doc "Returns true when the response has text content and no tool calls."
  def text_only?(%__MODULE__{} = r), do: not has_tool_calls?(r) and is_binary(r.content)
end
