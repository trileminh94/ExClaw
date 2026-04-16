defmodule ExClaw.Repo.Migrations.CreateSkills do
  use Ecto.Migration

  def change do
    create table(:skills, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :tier, :string, default: "global", null: false
      add :agent_id, :binary_id
      add :user_id, :string
      add :team_id, :binary_id
      add :session_id, :binary_id
      add :content, :text, null: false
      add :tags, {:array, :string}, default: []
      timestamps(type: :utc_datetime_usec)
    end

    # FTS5 virtual table for BM25 skill search — managed via raw SQL
    execute(
      """
      CREATE VIRTUAL TABLE IF NOT EXISTS skills_fts USING fts5(
        skill_id UNINDEXED,
        name,
        content,
        tokenize='porter ascii'
      )
      """,
      "DROP TABLE IF EXISTS skills_fts"
    )

    create index(:skills, [:tier])
    create index(:skills, [:agent_id])
  end
end
