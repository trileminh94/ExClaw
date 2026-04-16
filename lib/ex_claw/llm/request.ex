defmodule ExClaw.LLM.Request do
  @moduledoc "Canonical LLM request passed to any provider."

  @type thinking_config :: %{enabled: boolean(), budget_tokens: non_neg_integer()}

  @type t :: %__MODULE__{
          model: String.t(),
          messages: [map()],
          tools: [map()],
          system: String.t() | nil,
          max_tokens: non_neg_integer(),
          thinking: thinking_config() | nil,
          temperature: float() | nil,
          stream: boolean()
        }

  defstruct [
    :model,
    :system,
    :thinking,
    :temperature,
    messages: [],
    tools: [],
    max_tokens: 4096,
    stream: false
  ]
end
