defmodule ExClaw.Repo.Migrations.CreateAgents do
  use Ecto.Migration

  def change do
    create table(:agents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_key, :string
      add :name, :string, null: false
      add :type, :string, default: "open", null: false
      add :provider_id, :binary_id
      add :model, :string
      add :settings, :map, default: %{}
      add :user_id, :string
      add :tenant_id, :string
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:agents, [:agent_key])
    create index(:agents, [:user_id])
    create index(:agents, [:tenant_id])
  end
end
