defmodule ExClaw.Store.Schema.CronJob do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "cron_jobs" do
    field :name, :string
    field :agent_id, :binary_id
    field :user_id, :string
    field :tenant_id, :string
    # "cron" | "every" | "at"
    field :schedule_type, :string, default: "cron"
    field :schedule_expr, :string
    field :enabled, :boolean, default: true
    field :settings, :map, default: %{}
    field :last_run_at, :utc_datetime_usec
    field :next_run_at, :utc_datetime_usec
    timestamps()
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [:name, :agent_id, :user_id, :tenant_id, :schedule_type,
                    :schedule_expr, :enabled, :settings, :last_run_at, :next_run_at])
    |> validate_required([:name, :schedule_type, :schedule_expr])
    |> validate_inclusion(:schedule_type, ["cron", "every", "at"])
  end
end
