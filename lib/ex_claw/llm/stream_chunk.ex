defmodule ExClaw.LLM.StreamChunk do
  @moduledoc "A single streaming event sent to stream_pid during a chat_stream call."

  @type chunk_type :: :text_delta | :thinking_delta | :tool_call_start | :tool_call_delta | :done | :error

  @type t :: %__MODULE__{
          type: chunk_type(),
          content: String.t() | nil,
          tool_call_id: String.t() | nil,
          tool_name: String.t() | nil,
          final_response: ExClaw.LLM.Response.t() | nil,
          error: term() | nil
        }

  defstruct [
    :type,
    :content,
    :tool_call_id,
    :tool_name,
    :final_response,
    :error
  ]

  def text(content), do: %__MODULE__{type: :text_delta, content: content}
  def thinking(content), do: %__MODULE__{type: :thinking_delta, content: content}
  def done(response), do: %__MODULE__{type: :done, final_response: response}
  def error(reason), do: %__MODULE__{type: :error, error: reason}
end
