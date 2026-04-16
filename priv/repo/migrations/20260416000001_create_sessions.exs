defmodule ExClaw.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :agent_id, :binary_id
      add :user_id, :string
      add :tenant_id, :string
      add :status, :string, default: "idle", null: false
      add :metadata, :map, default: %{}
      timestamps(type: :utc_datetime_usec)
    end

    create index(:sessions, [:user_id])
    create index(:sessions, [:agent_id, :user_id])
    create index(:sessions, [:tenant_id])
  end
end
