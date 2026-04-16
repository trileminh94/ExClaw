defmodule ExClaw.LLM.SSEReader do
  @moduledoc """
  Pure-Elixir Server-Sent Events parser for LLM streaming responses.

  Parses the SSE wire format:
    data: {json}\\n\\n

  and emits decoded JSON maps for each event.
  """

  @doc """
  Parse a raw SSE binary chunk into a list of decoded event maps.
  Ignores comment lines (starting with ':') and 'data: [DONE]' sentinel.
  """
  @spec parse_chunk(binary()) :: [map()]
  def parse_chunk(chunk) when is_binary(chunk) do
    chunk
    |> String.split("\n")
    |> Enum.flat_map(&parse_line/1)
  end

  @doc "Stream a Req response body, calling `handler.(event_map)` for each SSE event."
  def stream_body(response_body, handler) when is_function(handler, 1) do
    response_body
    |> parse_chunk()
    |> Enum.each(handler)
  end

  # -- Private --

  defp parse_line("data: [DONE]"), do: []
  defp parse_line("data: " <> json) do
    case Jason.decode(json) do
      {:ok, map} -> [map]
      {:error, _} -> []
    end
  end
  defp parse_line(_), do: []
end
