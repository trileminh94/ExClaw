defmodule ExClaw.Repo.Migrations.CreateKnowledgeFts do
  use Ecto.Migration

  def up do
    execute("""
    CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_fts USING fts5(
      path UNINDEXED,
      content,
      last_modified UNINDEXED,
      content='',
      tokenize='porter ascii'
    )
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS knowledge_fts")
  end
end
