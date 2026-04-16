defmodule ExClaw.Gateway.WSHandler do
  @moduledoc """
  WebSocket connection handler — one process per connected client.

  Lifecycle:
  1. `init/1` — called by Bandit with the Plug.Conn at upgrade time.
     Extracts and validates the Bearer token from the `Authorization` header
     (or `?token=` query param for WS clients that can't set headers).
     Rejects unauthenticated connections immediately.
  2. `handle_in/2` — called by Bandit for each incoming text/binary frame.
     Decodes the frame as a Protocol request, dispatches via MethodRouter,
     and replies with the encoded result or error.
  3. `handle_info/2` — receives `:push_frame` messages from async tasks
     (streaming pipeline chunks forwarded here via EventBus → Task).
  4. `terminate/2` — cleanup on disconnect.

  EventBus subscription for streaming:
  When `chat.send` with `stream: true` is received, Methods.Chat subscribes
  the WS process to `{:session, session_id}` events. Pipeline stages publish
  `{:chunk, session_id, content}` and `{:done, session_id}` events which
  arrive here as regular process messages and are forwarded to the client.
  """

  @behaviour WebSock

  require Logger

  alias ExClaw.Auth.{Context, TokenAuth}
  alias ExClaw.Gateway.{Protocol, MethodRouter, RateLimiter}

  # State carried for the lifetime of the connection
  defstruct [:auth, :remote_ip, :streaming_session_id]

  # -- WebSock callbacks --

  @impl WebSock
  def init(options) do
    conn = Keyword.fetch!(options, :conn)
    remote_ip = remote_ip(conn)

    with :ok <- RateLimiter.check(remote_ip),
         {:ok, token} <- extract_token(conn),
         {:ok, %Context{} = auth} <- TokenAuth.authenticate(token) do
      Logger.debug("[WS] #{remote_ip} connected as #{auth.user_id} (#{auth.role})")
      {:ok, %__MODULE__{auth: auth, remote_ip: remote_ip}}
    else
      {:error, :rate_limited} ->
        {:stop, :normal, {429, "Too Many Requests"}, []}

      {:error, :no_token} ->
        {:stop, :normal, {401, "Unauthorized"}, []}

      {:error, :unauthorized} ->
        {:stop, :normal, {401, "Unauthorized"}, []}
    end
  end

  @impl WebSock
  def handle_in({raw, [opcode: :text]}, state) do
    case Protocol.decode(raw) do
      {:ok, %{id: id, method: method, params: params}} ->
        result = MethodRouter.dispatch(method, params, state.auth, self())
        frame = encode_result(id, result)
        {:push, [{:text, frame}], state}

      {:error, reason} ->
        {code, msg} = Protocol.error_bad_request()
        frame = Protocol.encode_error(nil, code, "#{msg}: #{inspect(reason)}")
        {:push, [{:text, frame}], state}
    end
  end

  def handle_in({_raw, [opcode: :binary]}, state) do
    # Binary frames not supported — ignore
    {:ok, state}
  end

  # StreamChunk messages sent directly from the LLM provider via stream_pid
  @impl WebSock
  def handle_info(%ExClaw.LLM.StreamChunk{type: :text_delta, content: content} = chunk, state) do
    session_id = Map.get(state, :streaming_session_id)
    frame = Protocol.encode_event("chunk", %{session_id: session_id, content: content})
    _ = chunk
    {:push, [{:text, frame}], state}
  end

  def handle_info(%ExClaw.LLM.StreamChunk{type: :done}, state) do
    session_id = Map.get(state, :streaming_session_id)
    frame = Protocol.encode_event("done", %{session_id: session_id})
    {:push, [{:text, frame}], %{state | streaming_session_id: nil}}
  end

  def handle_info(%ExClaw.LLM.StreamChunk{type: :error, error: reason}, state) do
    session_id = Map.get(state, :streaming_session_id)
    frame = Protocol.encode_event("error", %{session_id: session_id, message: inspect(reason)})
    {:push, [{:text, frame}], %{state | streaming_session_id: nil}}
  end

  def handle_info(%ExClaw.LLM.StreamChunk{}, state) do
    # Other chunk types (thinking_delta, tool_call_*) — not forwarded to client
    {:ok, state}
  end

  # EventBus events from async tasks (chat.send with stream: true)
  def handle_info({:chunk, session_id, content}, state) do
    frame = Protocol.encode_event("chunk", %{session_id: session_id, content: content})
    {:push, [{:text, frame}], state}
  end

  def handle_info({:done, session_id}, state) do
    frame = Protocol.encode_event("done", %{session_id: session_id})
    {:push, [{:text, frame}], state}
  end

  # Push arbitrary pre-encoded frames (e.g. from error callbacks in Tasks)
  def handle_info({:push_frame, encoded}, state) when is_binary(encoded) do
    {:push, [{:text, encoded}], state}
  end

  # Set current streaming session context before a streaming call starts
  def handle_info({:set_streaming_session, sid}, state) do
    {:ok, Map.put(state, :streaming_session_id, sid)}
  end

  def handle_info(msg, state) do
    Logger.debug("[WS] unexpected message: #{inspect(msg)}")
    {:ok, state}
  end

  @impl WebSock
  def terminate(reason, state) do
    if state != nil do
      Logger.debug("[WS] #{state.remote_ip} disconnected: #{inspect(reason)}")
    end

    :ok
  end

  # -- Private helpers --

  defp encode_result(id, {:ok, result}) do
    Protocol.encode_result(id, result)
  end

  defp encode_result(id, {:async, session_id}) do
    Protocol.encode_result(id, %{status: "streaming", session_id: session_id})
  end

  defp encode_result(id, {:error, code, message}) do
    Protocol.encode_error(id, code, message)
  end

  defp extract_token(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token | _] -> {:ok, String.trim(token)}
      ["bearer " <> token | _] -> {:ok, String.trim(token)}
      _ ->
        # Fallback: ?token= query param (some WS clients can't set headers)
        case conn.query_params["token"] do
          nil   -> {:error, :no_token}
          token -> {:ok, token}
        end
    end
  end

  defp remote_ip(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end
end
