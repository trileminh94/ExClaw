defmodule ExClaw.Repo.Migrations.CreateAPIKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key_hash, :string, null: false
      add :description, :string
      add :user_id, :string, null: false
      add :tenant_id, :string
      add :role, :string, default: "operator", null: false
      add :last_used_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:api_keys, [:key_hash])
    create index(:api_keys, [:user_id])
  end
end
