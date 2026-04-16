defmodule ExClaw.Gateway.Methods.Agents do
  @moduledoc """
  WebSocket method handlers for agent management.

  Methods:
  - `agent.create` — create an agent record
  - `agent.list`   — list agents for the tenant
  - `agent.get`    — get agent details
  - `agent.update` — update agent settings
  - `agent.delete` — delete an agent
  """

  alias ExClaw.Auth.{Context, RBAC}
  alias ExClaw.StoreSQLite.Agent, as: AgentStore

  def handle(method, params, %Context{} = auth) do
    case method do
      "agent.create" -> create(params, auth)
      "agent.list"   -> list(params, auth)
      "agent.get"    -> get(params, auth)
      "agent.update" -> update(params, auth)
      "agent.delete" -> delete(params, auth)
      _              -> {:error, 404, "method not found"}
    end
  end

  defp create(params, auth) do
    with :ok <- RBAC.check_permission(auth, :agent_create) do
      attrs = Map.merge(params, %{"tenant_id" => auth.tenant_id})
      case AgentStore.create_agent(attrs) do
        {:ok, agent} -> {:ok, agent_to_map(agent)}
        {:error, changeset} -> {:error, 422, format_errors(changeset)}
      end
    else
      {:error, :forbidden} -> {:error, 403, "forbidden"}
    end
  end

  defp list(_params, auth) do
    with :ok <- RBAC.check_permission(auth, :agent_list) do
      case AgentStore.list_agents(auth.tenant_id) do
        {:ok, agents} -> {:ok, %{agents: Enum.map(agents, &agent_to_map/1)}}
        {:error, reason} -> {:error, 500, inspect(reason)}
      end
    else
      {:error, :forbidden} -> {:error, 403, "forbidden"}
    end
  end

  defp get(%{"agent_id" => aid}, auth) do
    with :ok <- RBAC.check_permission(auth, :agent_read) do
      case AgentStore.get_agent(aid) do
        {:ok, agent} -> {:ok, agent_to_map(agent)}
        {:error, :not_found} -> {:error, 404, "agent not found"}
        {:error, reason} -> {:error, 500, inspect(reason)}
      end
    else
      {:error, :forbidden} -> {:error, 403, "forbidden"}
    end
  end

  defp get(_, _auth), do: {:error, 400, "agent_id required"}

  defp update(%{"agent_id" => aid} = params, auth) do
    with :ok <- RBAC.check_permission(auth, :agent_update) do
      attrs = Map.drop(params, ["agent_id"])
      case AgentStore.update_agent(aid, attrs) do
        {:ok, agent} -> {:ok, agent_to_map(agent)}
        {:error, :not_found} -> {:error, 404, "agent not found"}
        {:error, changeset} -> {:error, 422, format_errors(changeset)}
      end
    else
      {:error, :forbidden} -> {:error, 403, "forbidden"}
    end
  end

  defp update(_, _auth), do: {:error, 400, "agent_id required"}

  defp delete(%{"agent_id" => aid}, auth) do
    with :ok <- RBAC.check_permission(auth, :agent_delete) do
      case AgentStore.delete_agent(aid) do
        :ok -> {:ok, %{agent_id: aid, deleted: true}}
        {:error, :not_found} -> {:error, 404, "agent not found"}
        {:error, reason} -> {:error, 500, inspect(reason)}
      end
    else
      {:error, :forbidden} -> {:error, 403, "forbidden"}
    end
  end

  defp delete(_, _auth), do: {:error, 400, "agent_id required"}

  defp agent_to_map(a) do
    %{
      id: a.id,
      agent_key: a.agent_key,
      name: a.name,
      type: a.type,
      tenant_id: a.tenant_id,
      settings: a.settings,
      inserted_at: a.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
    |> Jason.encode!()
  end
end
