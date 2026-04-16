defmodule ExClaw.HTTP.Router do
  @moduledoc """
  HTTP REST API router.

  All routes except `/health` require Bearer auth (AuthPlug).
  Rate limiting applied globally (RateLimitPlug).

  Route map:
  GET  /health                        — unauthenticated health check
  POST /v1/chat/completions           — OpenAI-compat chat (auth required)

  GET  /v1/agents                     — list agents
  POST /v1/agents                     — create agent
  GET  /v1/agents/:id                 — get agent
  PUT  /v1/agents/:id                 — update agent
  DELETE /v1/agents/:id               — delete agent

  GET  /v1/sessions                   — list sessions
  POST /v1/sessions                   — create session
  GET  /v1/sessions/:id               — get session
  DELETE /v1/sessions/:id             — delete session

  GET  /v1/api-keys                   — list API keys
  POST /v1/api-keys                   — create API key
  DELETE /v1/api-keys/:id             — revoke API key
  """

  use Plug.Router
  require Logger

  alias ExClaw.Auth.RBAC
  alias ExClaw.HTTP.{OpenAICompat, Plug.AuthPlug, Plug.RateLimitPlug}
  alias ExClaw.StoreSQLite

  plug RateLimitPlug
  plug Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Jason
  plug :match
  plug :dispatch

  # -- WebSocket upgrade --

  get "/ws" do
    conn
    |> WebSockAdapter.upgrade(ExClaw.Gateway.WSHandler, [conn: conn], timeout: 60_000)
    |> halt()
  end

  # -- Health (no auth) --

  get "/health" do
    json(conn, 200, %{status: "ok"})
  end

  # -- OpenAI-compat --

  post "/v1/chat/completions" do
    with_auth(conn, fn conn, auth ->
      OpenAICompat.handle(conn, auth)
    end)
  end

  # -- Agents --

  get "/v1/agents" do
    with_auth(conn, fn conn, auth ->
      require_permission(conn, auth, :agent_list, fn ->
        case StoreSQLite.Agent.list_agents(auth.tenant_id) do
          {:ok, agents} -> json(conn, 200, %{agents: Enum.map(agents, &agent_map/1)})
          {:error, r}   -> json(conn, 500, %{error: inspect(r)})
        end
      end)
    end)
  end

  post "/v1/agents" do
    with_auth(conn, fn conn, auth ->
      require_permission(conn, auth, :agent_create, fn ->
        attrs = Map.merge(conn.body_params, %{"tenant_id" => auth.tenant_id})
        case StoreSQLite.Agent.create_agent(attrs) do
          {:ok, agent}        -> json(conn, 201, agent_map(agent))
          {:error, changeset} -> json(conn, 422, format_errors(changeset))
        end
      end)
    end)
  end

  get "/v1/agents/:id" do
    with_auth(conn, fn conn, auth ->
      require_permission(conn, auth, :agent_read, fn ->
        case StoreSQLite.Agent.get_agent(id) do
          {:ok, agent}         -> json(conn, 200, agent_map(agent))
          {:error, :not_found} -> json(conn, 404, %{error: "not found"})
        end
      end)
    end)
  end

  put "/v1/agents/:id" do
    with_auth(conn, fn conn, auth ->
      require_permission(conn, auth, :agent_update, fn ->
        case StoreSQLite.Agent.update_agent(id, conn.body_params) do
          {:ok, agent}         -> json(conn, 200, agent_map(agent))
          {:error, :not_found} -> json(conn, 404, %{error: "not found"})
          {:error, cs}         -> json(conn, 422, format_errors(cs))
        end
      end)
    end)
  end

  delete "/v1/agents/:id" do
    with_auth(conn, fn conn, auth ->
      require_permission(conn, auth, :agent_delete, fn ->
        case StoreSQLite.Agent.delete_agent(id) do
          :ok                  -> json(conn, 200, %{id: id, deleted: true})
          {:error, :not_found} -> json(conn, 404, %{error: "not found"})
        end
      end)
    end)
  end

  # -- Sessions --

  get "/v1/sessions" do
    with_auth(conn, fn conn, auth ->
      require_permission(conn, auth, :session_list, fn ->
        case StoreSQLite.Session.list_sessions(auth.user_id) do
          {:ok, sessions} -> json(conn, 200, %{sessions: Enum.map(sessions, &session_map/1)})
          {:error, r}     -> json(conn, 500, %{error: inspect(r)})
        end
      end)
    end)
  end

  post "/v1/sessions" do
    with_auth(conn, fn conn, auth ->
      require_permission(conn, auth, :session_create, fn ->
        session_id = Ecto.UUID.generate()
        agent_id = conn.body_params["agent_id"]

        opts = [
          session_id: session_id,
          agent_id: agent_id,
          user_id: auth.user_id,
          tenant_id: auth.tenant_id
        ]

        case DynamicSupervisor.start_child(ExClaw.Session.Supervisor, {ExClaw.Session, opts}) do
          {:ok, _}    -> json(conn, 201, %{session_id: session_id, status: "idle"})
          {:error, r} -> json(conn, 500, %{error: inspect(r)})
        end
      end)
    end)
  end

  get "/v1/sessions/:id" do
    with_auth(conn, fn conn, auth ->
      require_permission(conn, auth, :session_read, fn ->
        case StoreSQLite.Session.get_session(id) do
          {:ok, s}             -> json(conn, 200, session_map(s))
          {:error, :not_found} -> json(conn, 404, %{error: "not found"})
        end
      end)
    end)
  end

  delete "/v1/sessions/:id" do
    with_auth(conn, fn conn, auth ->
      require_permission(conn, auth, :session_delete, fn ->
        via = {:via, Registry, {ExClaw.Registry, {:session, id}}}
        case GenServer.whereis(via) do
          nil ->
            json(conn, 404, %{error: "session not found or not running"})
          pid ->
            DynamicSupervisor.terminate_child(ExClaw.Session.Supervisor, pid)
            json(conn, 200, %{id: id, deleted: true})
        end
      end)
    end)
  end

  # -- API Keys --

  get "/v1/api-keys" do
    with_auth(conn, fn conn, auth ->
      require_permission(conn, auth, :api_key_list, fn ->
        case StoreSQLite.APIKey.list_keys(auth.user_id) do
          {:ok, keys} -> json(conn, 200, %{keys: Enum.map(keys, &key_map/1)})
          {:error, r} -> json(conn, 500, %{error: inspect(r)})
        end
      end)
    end)
  end

  post "/v1/api-keys" do
    with_auth(conn, fn conn, auth ->
      require_permission(conn, auth, :api_key_create, fn ->
        raw_token = generate_token()
        attrs = %{
          key_hash: ExClaw.Auth.TokenAuth.hash_token(raw_token),
          description: conn.body_params["description"],
          user_id: auth.user_id,
          tenant_id: auth.tenant_id,
          role: Map.get(conn.body_params, "role", "operator")
        }

        case StoreSQLite.APIKey.create_key(attrs) do
          {:ok, key} ->
            # Return the raw token once — it cannot be retrieved again
            json(conn, 201, Map.put(key_map(key), :token, raw_token))
          {:error, cs} ->
            json(conn, 422, format_errors(cs))
        end
      end)
    end)
  end

  delete "/v1/api-keys/:id" do
    with_auth(conn, fn conn, auth ->
      require_permission(conn, auth, :api_key_revoke, fn ->
        case StoreSQLite.APIKey.delete_key(id) do
          :ok                  -> json(conn, 200, %{id: id, revoked: true})
          {:error, :not_found} -> json(conn, 404, %{error: "not found"})
        end
      end)
    end)
  end

  # -- Catch-all --

  match _ do
    json(conn, 404, %{error: "not found"})
  end

  # -- Private helpers --

  defp with_auth(conn, fun) do
    conn = AuthPlug.call(conn, [])
    if conn.halted, do: conn, else: fun.(conn, conn.assigns.auth)
  end

  defp require_permission(conn, auth, permission, fun) do
    case RBAC.check_permission(auth, permission) do
      :ok              -> fun.()
      {:error, :forbidden} -> json(conn, 403, %{error: "forbidden"})
    end
  end

  defp json(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Jason.encode!(body))
  end

  defp agent_map(a) do
    %{id: a.id, agent_key: a.agent_key, name: a.name,
      type: a.type, tenant_id: a.tenant_id, settings: a.settings,
      inserted_at: a.inserted_at}
  end

  defp session_map(s) do
    %{id: s.id, agent_id: s.agent_id, user_id: s.user_id,
      tenant_id: s.tenant_id, status: s.status, inserted_at: s.inserted_at}
  end

  defp key_map(k) do
    %{id: k.id, description: k.description, user_id: k.user_id,
      tenant_id: k.tenant_id, role: k.role,
      last_used_at: k.last_used_at, inserted_at: k.inserted_at}
  end

  defp format_errors(changeset) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)}
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
