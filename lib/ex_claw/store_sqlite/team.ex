defmodule ExClaw.StoreSQLite.Team do
  @moduledoc "SQLite implementation of ExClaw.Store.TeamStore."
  @behaviour ExClaw.Store.TeamStore

  import Ecto.Query
  alias ExClaw.Repo
  alias ExClaw.Store.Schema.{Team, TeamTask, TeamMessage}

  @impl true
  def create_team(attrs) do
    %Team{} |> Team.changeset(attrs) |> Repo.insert() |> result()
  end

  @impl true
  def get_team(id) do
    case Repo.get(Team, id) do
      nil -> {:error, :not_found}
      t -> {:ok, t}
    end
  end

  @impl true
  def list_teams(opts) do
    query = from(t in Team, order_by: [asc: t.name])

    query =
      case Map.get(opts, :user_id) do
        nil -> query
        uid -> from(t in query, where: t.user_id == ^uid)
      end

    {:ok, Repo.all(query)}
  end

  @impl true
  def delete_team(id) do
    case Repo.get(Team, id) do
      nil -> {:error, :not_found}
      t -> Repo.delete(t) |> delete_result()
    end
  end

  @impl true
  def create_task(attrs) do
    %TeamTask{} |> TeamTask.changeset(attrs) |> Repo.insert() |> result()
  end

  @impl true
  def get_task(id) do
    case Repo.get(TeamTask, id) do
      nil -> {:error, :not_found}
      t -> {:ok, t}
    end
  end

  @impl true
  def list_tasks(team_id, opts) do
    query = from(t in TeamTask, where: t.team_id == ^team_id, order_by: [asc: t.inserted_at])

    query =
      case Map.get(opts, :status) do
        nil -> query
        status -> from(t in query, where: t.status == ^status)
      end

    {:ok, Repo.all(query)}
  end

  @impl true
  def update_task(id, attrs) do
    case Repo.get(TeamTask, id) do
      nil -> {:error, :not_found}
      t -> t |> TeamTask.changeset(attrs) |> Repo.update() |> result()
    end
  end

  @impl true
  def claim_task(task_id, worker_id) do
    # Atomic compare-and-swap: update status=claimed only if currently pending
    {count, _} =
      from(t in TeamTask,
        where: t.id == ^task_id and t.status == "pending"
      )
      |> Repo.update_all(set: [status: "claimed", worker_agent_id: worker_id])

    case count do
      0 ->
        case Repo.get(TeamTask, task_id) do
          nil -> {:error, :not_found}
          _ -> {:error, :already_claimed}
        end

      _ ->
        {:ok, Repo.get!(TeamTask, task_id)}
    end
  end

  @impl true
  def append_team_message(attrs) do
    %TeamMessage{} |> TeamMessage.changeset(attrs) |> Repo.insert() |> result()
  end

  @impl true
  def list_team_messages(team_id, limit) do
    msgs =
      from(m in TeamMessage,
        where: m.team_id == ^team_id,
        order_by: [desc: m.inserted_at],
        limit: ^limit
      )
      |> Repo.all()
      |> Enum.reverse()

    {:ok, msgs}
  end

  defp result({:ok, struct}), do: {:ok, struct}
  defp result({:error, changeset}), do: {:error, changeset}

  defp delete_result({:ok, _}), do: :ok
  defp delete_result({:error, reason}), do: {:error, reason}
end
