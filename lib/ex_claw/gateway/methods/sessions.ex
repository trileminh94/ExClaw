defmodule ExClaw.Gateway.Methods.Sessions do
  @moduledoc """
  WebSocket method handlers for session lifecycle management.

  Methods:
  - `session.create` — create a new session (starts a Session GenServer)
  - `session.list`   — list sessions for the current user
  - `session.get`    — get session details
  - `session.delete` — terminate a session
  """

  alias ExClaw.Auth.{Context, RBAC}
  alias ExClaw.{Session, Session.Supervisor, StoreSQLite}

  def handle(method, params, %Context{} = auth) do
    case method do
      "session.create" -> create(params, auth)
      "session.list"   -> list(params, auth)
      "session.get"    -> get(params, auth)
      "session.delete" -> delete(params, auth)
      _                -> {:error, 404, "method not found"}
    end
  end

  defp create(params, auth) do
    with :ok <- RBAC.check_permission(auth, :session_create) do
      agent_id = Map.get(params, "agent_id")
      session_id = Map.get(params, "session_id", generate_id())

      opts = [
        session_id: session_id,
        agent_id: agent_id,
        user_id: auth.user_id,
        tenant_id: auth.tenant_id
      ]

      case DynamicSupervisor.start_child(Supervisor, {Session, opts}) do
        {:ok, _pid} ->
          {:ok, %{session_id: session_id, status: "idle"}}
        {:error, {:already_started, _}} ->
          {:ok, %{session_id: session_id, status: "existing"}}
        {:error, reason} ->
          {:error, 500, inspect(reason)}
      end
    else
      {:error, :forbidden} -> {:error, 403, "forbidden"}
    end
  end

  defp list(_params, auth) do
    with :ok <- RBAC.check_permission(auth, :session_list) do
      case StoreSQLite.Session.list_sessions(auth.user_id) do
        {:ok, sessions} ->
          items = Enum.map(sessions, &session_to_map/1)
          {:ok, %{sessions: items}}
        {:error, reason} ->
          {:error, 500, inspect(reason)}
      end
    else
      {:error, :forbidden} -> {:error, 403, "forbidden"}
    end
  end

  defp get(%{"session_id" => sid}, auth) do
    with :ok <- RBAC.check_permission(auth, :session_read) do
      case StoreSQLite.Session.get_session(sid) do
        {:ok, session} -> {:ok, session_to_map(session)}
        {:error, :not_found} -> {:error, 404, "session not found"}
        {:error, reason} -> {:error, 500, inspect(reason)}
      end
    else
      {:error, :forbidden} -> {:error, 403, "forbidden"}
    end
  end

  defp get(_, _auth), do: {:error, 400, "session_id required"}

  defp delete(%{"session_id" => sid}, auth) do
    with :ok <- RBAC.check_permission(auth, :session_delete) do
      via = {:via, Registry, {ExClaw.Registry, {:session, sid}}}
      case GenServer.whereis(via) do
        nil -> {:error, 404, "session not found"}
        pid ->
          DynamicSupervisor.terminate_child(ExClaw.Session.Supervisor, pid)
          {:ok, %{session_id: sid, deleted: true}}
      end
    else
      {:error, :forbidden} -> {:error, 403, "forbidden"}
    end
  end

  defp delete(_, _auth), do: {:error, 400, "session_id required"}

  defp session_to_map(s) do
    %{
      id: s.id,
      agent_id: s.agent_id,
      user_id: s.user_id,
      tenant_id: s.tenant_id,
      status: s.status,
      inserted_at: s.inserted_at
    }
  end

  defp generate_id, do: Ecto.UUID.generate()
end
