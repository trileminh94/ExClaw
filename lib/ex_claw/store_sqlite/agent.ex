defmodule ExClaw.StoreSQLite.Agent do
  @moduledoc "SQLite implementation of ExClaw.Store.AgentStore."
  @behaviour ExClaw.Store.AgentStore

  import Ecto.Query
  alias ExClaw.Repo
  alias ExClaw.Store.Schema.Agent

  @impl true
  def create_agent(attrs) do
    %Agent{}
    |> Agent.changeset(attrs)
    |> Repo.insert()
    |> result()
  end

  @impl true
  def get_agent(id) do
    case Repo.get(Agent, id) do
      nil -> {:error, :not_found}
      agent -> {:ok, agent}
    end
  end

  @impl true
  def get_agent_by_key(key) do
    case Repo.get_by(Agent, agent_key: key) do
      nil -> {:error, :not_found}
      agent -> {:ok, agent}
    end
  end

  @impl true
  def list_agents(opts) do
    query = from(a in Agent, order_by: [asc: a.name])

    query =
      case Map.get(opts, :user_id) do
        nil -> query
        uid -> from(a in query, where: a.user_id == ^uid)
      end

    query =
      case Map.get(opts, :tenant_id) do
        nil -> query
        tid -> from(a in query, where: a.tenant_id == ^tid)
      end

    {:ok, Repo.all(query)}
  end

  @impl true
  def update_agent(id, attrs) do
    case Repo.get(Agent, id) do
      nil -> {:error, :not_found}
      agent -> agent |> Agent.changeset(attrs) |> Repo.update() |> result()
    end
  end

  @impl true
  def delete_agent(id) do
    case Repo.get(Agent, id) do
      nil -> {:error, :not_found}
      agent -> Repo.delete(agent) |> delete_result()
    end
  end

  defp result({:ok, struct}), do: {:ok, struct}
  defp result({:error, changeset}), do: {:error, changeset}

  defp delete_result({:ok, _}), do: :ok
  defp delete_result({:error, reason}), do: {:error, reason}
end
