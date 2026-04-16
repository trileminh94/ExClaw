defmodule ExClaw.HTTP.OpenAICompat do
  @moduledoc """
  OpenAI-compatible chat completions endpoint.

  POST /v1/chat/completions

  Accepts a subset of the OpenAI API request format and returns a response
  in OpenAI format, allowing ExClaw to be used as a drop-in backend for
  any OpenAI-compatible client.

  Non-streaming: returns a single `chat.completion` object.
  Streaming: returns SSE events in OpenAI delta format.
  """

  import Plug.Conn
  alias ExClaw.{Session, EventBus}

  def handle(%Plug.Conn{} = conn, auth) do
    with {:ok, body, conn} <- read_body(conn),
         {:ok, req} <- Jason.decode(body) do
      messages = Map.get(req, "messages", [])
      stream = Map.get(req, "stream", false)
      session_id = Ecto.UUID.generate()

      # Start an ephemeral session for this request
      opts = [
        session_id: session_id,
        user_id: auth.user_id,
        tenant_id: auth.tenant_id
      ]

      {:ok, _pid} = DynamicSupervisor.start_child(
        ExClaw.Session.Supervisor,
        {ExClaw.Session, opts}
      )

      last_user = find_last_user_message(messages)

      if stream do
        handle_streaming(conn, session_id, last_user)
      else
        handle_blocking(conn, session_id, last_user)
      end
    else
      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: %{message: inspect(reason)}}))
    end
  end

  defp handle_blocking(conn, session_id, text) do
    case Session.send_message(session_id, text) do
      {:ok, content} ->
        resp = build_completion(session_id, content)
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(resp))

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(%{error: %{message: inspect(reason)}}))
    end
  end

  defp handle_streaming(conn, session_id, text) do
    EventBus.subscribe({:session, session_id})

    # Kick off run in background Task
    Task.start(fn -> Session.send_message(session_id, text) end)

    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> send_chunked(200)

    stream_sse(conn, session_id)
  end

  defp stream_sse(conn, session_id) do
    receive do
      {:chunk, ^session_id, content} ->
        delta = build_delta(session_id, content)
        chunk_data = "data: #{Jason.encode!(delta)}\n\n"
        case chunk(conn, chunk_data) do
          {:ok, conn} -> stream_sse(conn, session_id)
          {:error, _} -> conn
        end

      {:done, ^session_id} ->
        EventBus.unsubscribe({:session, session_id})
        chunk(conn, "data: [DONE]\n\n")
        conn

      _ ->
        stream_sse(conn, session_id)
    after
      120_000 ->
        EventBus.unsubscribe({:session, session_id})
        conn
    end
  end

  defp find_last_user_message(messages) do
    messages
    |> Enum.filter(fn m -> Map.get(m, "role") == "user" end)
    |> List.last()
    |> case do
      nil -> ""
      m -> Map.get(m, "content", "")
    end
  end

  defp build_completion(id, content) do
    %{
      id: "chatcmpl-#{id}",
      object: "chat.completion",
      created: System.system_time(:second),
      model: Application.get_env(:ex_claw, :model, "claude-opus-4-6"),
      choices: [
        %{
          index: 0,
          message: %{role: "assistant", content: content},
          finish_reason: "stop"
        }
      ]
    }
  end

  defp build_delta(id, content) do
    %{
      id: "chatcmpl-#{id}",
      object: "chat.completion.chunk",
      created: System.system_time(:second),
      model: Application.get_env(:ex_claw, :model, "claude-opus-4-6"),
      choices: [
        %{
          index: 0,
          delta: %{role: "assistant", content: content},
          finish_reason: nil
        }
      ]
    }
  end
end
