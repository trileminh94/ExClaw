defmodule ExClaw.Store.Schema.Skill do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "skills" do
    field :name, :string
    # "global" | "agent" | "user" | "team" | "session"
    field :tier, :string, default: "global"
    field :agent_id, :binary_id
    field :user_id, :string
    field :team_id, :binary_id
    field :session_id, :binary_id
    field :content, :string
    field :tags, {:array, :string}, default: []
    timestamps()
  end

  def changeset(skill, attrs) do
    skill
    |> cast(attrs, [:name, :tier, :agent_id, :user_id, :team_id, :session_id, :content, :tags])
    |> validate_required([:name, :content])
    |> validate_inclusion(:tier, ["global", "agent", "user", "team", "session"])
  end
end
