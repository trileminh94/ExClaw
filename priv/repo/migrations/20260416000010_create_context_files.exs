defmodule ExClaw.Repo.Migrations.CreateContextFiles do
  use Ecto.Migration

  def change do
    create table(:agent_context_files, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, :binary_id, null: false
      add :filename, :string, null: false
      add :content, :text, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create table(:user_context_files, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, :binary_id, null: false
      add :user_id, :string, null: false
      add :filename, :string, null: false
      add :content, :text, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:agent_context_files, [:agent_id, :filename])
    create unique_index(:user_context_files, [:agent_id, :user_id, :filename])
  end
end
