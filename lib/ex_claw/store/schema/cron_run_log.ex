defmodule ExClaw.Store.Schema.CronRunLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "cron_run_logs" do
    field :cron_job_id, :binary_id
    field :status, :string
    field :error, :string
    field :duration_ms, :integer
    field :session_id, :binary_id
    timestamps(updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:cron_job_id, :status, :error, :duration_ms, :session_id])
    |> validate_required([:cron_job_id, :status])
    |> validate_inclusion(:status, ["ok", "error", "running"])
  end
end
