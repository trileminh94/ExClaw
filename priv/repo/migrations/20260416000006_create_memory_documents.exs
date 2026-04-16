defmodule ExClaw.Repo.Migrations.CreateMemoryDocuments do
  use Ecto.Migration

  def change do
    create table(:memory_documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, :binary_id
      add :user_id, :string
      add :tenant_id, :string
      add :type, :string, default: "episodic", null: false
      add :content, :text, null: false
      add :summary, :text
      add :embedding, :text
      add :metadata, :map, default: %{}
      add :session_id, :binary_id
      timestamps(type: :utc_datetime_usec)
    end

    create index(:memory_documents, [:agent_id, :user_id])
    create index(:memory_documents, [:type])
  end
end
