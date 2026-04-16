defmodule ExClaw.Store.Schema.Team do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "teams" do
    field :name, :string
    field :lead_agent_id, :binary_id
    field :user_id, :string
    field :tenant_id, :string
    field :settings, :map, default: %{}
    timestamps()
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :lead_agent_id, :user_id, :tenant_id, :settings])
    |> validate_required([:name])
  end
end
