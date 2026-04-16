defmodule ExClaw.Gateway.Protocol do
  @moduledoc """
  WebSocket frame encode/decode for the ExClaw gateway protocol.

  Frame shape (JSON):

  Request  — client → server:
    {"id": "...", "method": "chat.send", "params": {...}}

  Response — server → client:
    {"id": "...", "result": {...}} | {"id": "...", "error": {"code": N, "message": "..."}}

  Event    — server → client (no id):
    {"event": "chunk",  "data": {"session_id": "...", "content": "..."}}
    {"event": "done",   "data": {"session_id": "..."}}
    {"event": "error",  "data": {"session_id": "...", "message": "..."}}
    {"event": "status", "data": {"session_id": "...", "status": "..."}}
  """

  # -- Decoding --

  @doc """
  Decode a raw WebSocket text frame into a request map.

  Returns `{:ok, %{id: id, method: method, params: params}}` or `{:error, reason}`.
  """
  @spec decode(binary()) :: {:ok, map()} | {:error, term()}
  def decode(raw) when is_binary(raw) do
    with {:ok, map} <- Jason.decode(raw),
         {:ok, id} <- fetch_field(map, "id"),
         {:ok, method} <- fetch_field(map, "method") do
      params = Map.get(map, "params", %{})
      {:ok, %{id: id, method: method, params: params}}
    end
  end

  # -- Encoding --

  @doc "Encode a success response frame."
  @spec encode_result(term(), term()) :: binary()
  def encode_result(id, result) do
    Jason.encode!(%{id: id, result: result})
  end

  @doc "Encode an error response frame."
  @spec encode_error(term(), integer(), String.t()) :: binary()
  def encode_error(id, code, message) do
    Jason.encode!(%{id: id, error: %{code: code, message: message}})
  end

  @doc "Encode an event frame (no request id)."
  @spec encode_event(String.t(), map()) :: binary()
  def encode_event(event, data) do
    Jason.encode!(%{event: event, data: data})
  end

  # Common error codes (matches HTTP semantics for convenience)
  def error_unauthorized,  do: {401, "unauthorized"}
  def error_forbidden,     do: {403, "forbidden"}
  def error_not_found,     do: {404, "not found"}
  def error_bad_request,   do: {400, "bad request"}
  def error_conflict,      do: {409, "conflict"}
  def error_internal,      do: {500, "internal server error"}

  # -- Private --

  defp fetch_field(map, key) do
    case Map.fetch(map, key) do
      {:ok, val} -> {:ok, val}
      :error -> {:error, {:missing_field, key}}
    end
  end
end
