defmodule ExClaw.Store.Schema.TeamTask do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "team_tasks" do
    field :team_id, :binary_id
    field :title, :string
    field :description, :string
    # "pending" | "claimed" | "in_progress" | "done" | "blocked" | "failed"
    field :status, :string, default: "pending"
    field :worker_agent_id, :binary_id
    field :result, :string
    field :metadata, :map, default: %{}
    timestamps()
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [:team_id, :title, :description, :status, :worker_agent_id, :result, :metadata])
    |> validate_required([:team_id, :title])
    |> validate_inclusion(:status, ["pending", "claimed", "in_progress", "done", "blocked", "failed"])
  end
end
