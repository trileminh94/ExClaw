defmodule ExClaw.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :agent_id, :binary_id
      add :user_id, :string
      add :tenant_id, :string
      add :role, :string, null: false
      add :content, :text
      add :tool_calls, :map
      add :tool_results, :map
      add :thinking, :text
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:messages, [:session_id])
    create index(:messages, [:session_id, :inserted_at])
  end
end
