defmodule ExClaw.Repo.Migrations.CreateProviders do
  use Ecto.Migration

  def change do
    create table(:llm_providers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :type, :string, null: false
      add :base_url, :string
      add :encrypted_api_key, :string
      add :default_model, :string
      add :settings, :map, default: %{}
      add :tenant_id, :string
      timestamps(type: :utc_datetime_usec)
    end

    create index(:llm_providers, [:tenant_id])
  end
end
