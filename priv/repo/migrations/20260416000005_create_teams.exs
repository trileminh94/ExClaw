defmodule ExClaw.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create table(:teams, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :lead_agent_id, :binary_id
      add :user_id, :string
      add :tenant_id, :string
      add :settings, :map, default: %{}
      timestamps(type: :utc_datetime_usec)
    end

    create table(:team_tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :description, :text
      add :status, :string, default: "pending", null: false
      add :worker_agent_id, :binary_id
      add :result, :text
      add :metadata, :map, default: %{}
      timestamps(type: :utc_datetime_usec)
    end

    create table(:team_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_id, references(:teams, type: :binary_id, on_delete: :delete_all), null: false
      add :from_agent_id, :binary_id
      add :content, :text, null: false
      add :metadata, :map, default: %{}
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:teams, [:user_id])
    create index(:team_tasks, [:team_id, :status])
    create index(:team_messages, [:team_id])
  end
end
