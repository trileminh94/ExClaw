defmodule ExClaw.StoreSQLite.Cron do
  @moduledoc "SQLite implementation of ExClaw.Store.CronStore."
  @behaviour ExClaw.Store.CronStore

  import Ecto.Query
  alias ExClaw.Repo
  alias ExClaw.Store.Schema.{CronJob, CronRunLog}

  @impl true
  def create_cron_job(attrs) do
    %CronJob{}
    |> CronJob.changeset(attrs)
    |> Repo.insert()
    |> result()
  end

  @impl true
  def get_cron_job(id) do
    case Repo.get(CronJob, id) do
      nil -> {:error, :not_found}
      job -> {:ok, job}
    end
  end

  @impl true
  def list_cron_jobs(opts) do
    query = from(j in CronJob, order_by: [asc: j.name])

    query =
      case Map.get(opts, :agent_id) do
        nil -> query
        aid -> from(j in query, where: j.agent_id == ^aid)
      end

    query =
      case Map.get(opts, :enabled) do
        nil -> query
        enabled -> from(j in query, where: j.enabled == ^enabled)
      end

    {:ok, Repo.all(query)}
  end

  @impl true
  def update_cron_job(id, attrs) do
    case Repo.get(CronJob, id) do
      nil -> {:error, :not_found}
      job -> job |> CronJob.changeset(attrs) |> Repo.update() |> result()
    end
  end

  @impl true
  def delete_cron_job(id) do
    case Repo.get(CronJob, id) do
      nil -> {:error, :not_found}
      job -> Repo.delete(job) |> delete_result()
    end
  end

  @impl true
  def append_run_log(attrs) do
    %CronRunLog{}
    |> CronRunLog.changeset(attrs)
    |> Repo.insert()
    |> result()
  end

  @impl true
  def list_run_logs(job_id, limit) do
    logs =
      from(l in CronRunLog,
        where: l.cron_job_id == ^job_id,
        order_by: [desc: l.inserted_at],
        limit: ^limit
      )
      |> Repo.all()

    {:ok, logs}
  end

  defp result({:ok, struct}), do: {:ok, struct}
  defp result({:error, changeset}), do: {:error, changeset}

  defp delete_result({:ok, _}), do: :ok
  defp delete_result({:error, reason}), do: {:error, reason}
end
