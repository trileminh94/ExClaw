defmodule ExClaw.Repo.Migrations.CreateCronJobs do
  use Ecto.Migration

  def change do
    create table(:cron_jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :agent_id, :binary_id
      add :user_id, :string
      add :tenant_id, :string
      add :schedule_type, :string, default: "cron", null: false
      add :schedule_expr, :string, null: false
      add :enabled, :boolean, default: true, null: false
      add :settings, :map, default: %{}
      add :last_run_at, :utc_datetime_usec
      add :next_run_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create table(:cron_run_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :cron_job_id, references(:cron_jobs, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false
      add :error, :text
      add :duration_ms, :integer
      add :session_id, :binary_id
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:cron_jobs, [:agent_id])
    create index(:cron_jobs, [:enabled])
    create index(:cron_run_logs, [:cron_job_id])
  end
end
