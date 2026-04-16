defmodule ExClaw.Store.Schema.APIKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "api_keys" do
    field :key_hash, :string
    field :description, :string
    field :user_id, :string
    field :tenant_id, :string
    # "admin" | "operator" | "viewer"
    field :role, :string, default: "operator"
    field :last_used_at, :utc_datetime_usec
    timestamps()
  end

  def changeset(key, attrs) do
    key
    |> cast(attrs, [:key_hash, :description, :user_id, :tenant_id, :role, :last_used_at])
    |> validate_required([:key_hash, :user_id])
    |> validate_inclusion(:role, ["admin", "operator", "viewer"])
    |> unique_constraint(:key_hash)
  end
end
