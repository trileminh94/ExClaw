defmodule ExClaw.Gateway.Methods.Chat do
  @moduledoc """
  WebSocket method handlers for chat operations.

  Methods:
  - `chat.send`    — send a user message to a session (streaming or blocking)
  - `chat.approve` — approve or deny a dangerous tool execution
  - `chat.status`  — get the current status of a session
  """

  alias ExClaw.Auth.{Context, RBAC}
  alias ExClaw.Session

  @doc "Handle a dispatched chat method."
  def handle(method, params, %Context{} = auth, ws_pid) do
    case method do
      "chat.send"    -> send_message(params, auth, ws_pid)
      "chat.approve" -> approve_tools(params, auth)
      "chat.status"  -> get_status(params, auth)
      _              -> {:error, 404, "method not found"}
    end
  end

  # -- Private handlers --

  defp send_message(%{"session_id" => sid, "content" => text} = params, auth, ws_pid) do
    with :ok <- RBAC.check_permission(auth, :chat_send) do
      stream = Map.get(params, "stream", false)

      if stream and ws_pid != nil do
        # Tell the WS handler which session's chunks to expect
        send(ws_pid, {:set_streaming_session, sid})

        # Run the session pipeline in a background Task so we don't block the
        # WS handler. stream_pid=ws_pid causes ThinkStage to call chat_stream/3
        # which delivers StreamChunk messages directly to the WS handler.
        Task.start(fn ->
          result = Session.send_message_stream(sid, text, ws_pid)

          case result do
            {:ok, _} ->
              :ok
            {:error, reason} ->
              frame = ExClaw.Gateway.Protocol.encode_event("error", %{
                session_id: sid, message: inspect(reason)})
              send(ws_pid, {:push_frame, frame})
          end
        end)

        {:async, sid}
      else
        case Session.send_message(sid, text) do
          {:ok, content}   -> {:ok, %{session_id: sid, content: content}}
          {:error, reason} -> {:error, 500, inspect(reason)}
        end
      end
    else
      {:error, :forbidden} -> {:error, 403, "forbidden"}
    end
  end

  defp send_message(_, _auth, _ws_pid), do: {:error, 400, "session_id and content required"}

  defp approve_tools(%{"session_id" => sid, "decision" => decision}, auth) do
    with :ok <- RBAC.check_permission(auth, :chat_approve) do
      atom = if decision in ["granted", true], do: :granted, else: :denied
      Session.approve_tools(sid, atom)
      {:ok, %{session_id: sid, decision: to_string(atom)}}
    else
      {:error, :forbidden} -> {:error, 403, "forbidden"}
    end
  end

  defp approve_tools(_, _auth), do: {:error, 400, "session_id and decision required"}

  defp get_status(%{"session_id" => sid}, auth) do
    with :ok <- RBAC.check_permission(auth, :session_read) do
      status = Session.get_status(sid)
      {:ok, %{session_id: sid, status: status}}
    else
      {:error, :forbidden} -> {:error, 403, "forbidden"}
    end
  end

  defp get_status(_, _auth), do: {:error, 400, "session_id required"}
end
