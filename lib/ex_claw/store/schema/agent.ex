defmodule ExClaw.Store.Schema.Agent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "agents" do
    field :agent_key, :string
    field :name, :string
    field :type, :string, default: "open"
    field :provider_id, :binary_id
    field :model, :string
    field :settings, :map, default: %{}
    field :user_id, :string
    field :tenant_id, :string
    timestamps()
  end

  def changeset(agent, attrs) do
    agent
    |> cast(attrs, [:agent_key, :name, :type, :provider_id, :model, :settings, :user_id, :tenant_id])
    |> validate_required([:name])
    |> validate_inclusion(:type, ["open", "predefined"])
    |> unique_constraint(:agent_key)
  end
end
