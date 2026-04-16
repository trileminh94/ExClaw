defmodule ExClaw.Pipeline.RunState do
  @moduledoc """
  Mutable state that flows through pipeline stages within a single run.

  Stages receive and return this struct. The executor threads it through each stage
  in sequence, up to max_iterations times.
  """

  alias ExClaw.Pipeline.RunInput
  alias ExClaw.LLM.Response

  @type t :: %__MODULE__{
          run_input: RunInput.t(),
          messages: [map()],
          iteration: non_neg_integer(),
          system_prompt: String.t() | nil,
          tool_definitions: [map()],
          last_response: Response.t() | nil,
          pending_tool_calls: [map()],
          tool_results: [map()],
          final_content: String.t() | nil,
          pending_db_messages: [map()],
          approved: boolean()
        }

  defstruct [
    :run_input,
    :system_prompt,
    :last_response,
    :final_content,
    messages: [],
    iteration: 0,
    tool_definitions: [],
    pending_tool_calls: [],
    tool_results: [],
    pending_db_messages: [],
    approved: false
  ]
end
