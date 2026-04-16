defmodule ExClaw.Store.Schema.Provider do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "llm_providers" do
    field :name, :string
    field :type, :string
    field :base_url, :string
    field :encrypted_api_key, :string
    field :default_model, :string
    field :settings, :map, default: %{}
    field :tenant_id, :string
    timestamps()
  end

  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [:name, :type, :base_url, :encrypted_api_key, :default_model, :settings, :tenant_id])
    |> validate_required([:name, :type])
  end
end
