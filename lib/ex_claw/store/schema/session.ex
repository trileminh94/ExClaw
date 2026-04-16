defmodule ExClaw.Store.Schema.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "sessions" do
    field :name, :string
    field :agent_id, :binary_id
    field :user_id, :string
    field :tenant_id, :string
    field :status, :string, default: "idle"
    field :metadata, :map, default: %{}
    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:name, :agent_id, :user_id, :tenant_id, :status, :metadata])
    |> validate_required([:name])
  end
end
