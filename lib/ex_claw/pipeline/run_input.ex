defmodule ExClaw.Pipeline.RunInput do
  @moduledoc """
  Immutable parameters for a single pipeline run.
  Built once per user message by the Session and threaded through all stages.
  """

  @type t :: %__MODULE__{
          session_id: String.t(),
          agent_id: String.t() | nil,
          user_id: String.t() | nil,
          tenant_id: String.t() | nil,
          provider_module: module(),
          provider_config: map(),
          pool_name: atom(),
          tools: [map()],
          max_iterations: non_neg_integer(),
          context_window: non_neg_integer(),
          stream_pid: pid() | nil
        }

  defstruct [
    :session_id,
    :agent_id,
    :user_id,
    :tenant_id,
    :provider_module,
    :stream_pid,
    provider_config: %{},
    pool_name: ExClaw.LLM.Pool,
    tools: [],
    max_iterations: 20,
    context_window: 200_000
  ]
end
