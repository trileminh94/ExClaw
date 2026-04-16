defmodule ExClaw.Repo do
  @moduledoc """
  Ecto repository backed by SQLite3 (via ecto_sqlite3).

  All domain queries go through the store_sqlite/ impl modules.
  This module retains raw SQL helpers for FTS5 virtual tables
  (knowledge_fts, skills_fts) that Ecto cannot manage natively.
  """
  use Ecto.Repo,
    otp_app: :ex_claw,
    adapter: Ecto.Adapters.SQLite3

  require Logger

  # -- FTS5: knowledge base --

  @doc "Insert or update a knowledge document in the FTS5 index."
  def upsert_knowledge(path, content, last_modified) do
    sql = """
    INSERT INTO knowledge_fts (path, content, last_modified)
    VALUES (?, ?, ?)
    ON CONFLICT(path) DO UPDATE SET
      content = excluded.content,
      last_modified = excluded.last_modified
    """

    case Ecto.Adapters.SQL.query(__MODULE__, sql, [path, content, last_modified]) do
      {:ok, _} -> :ok
      {:error, err} ->
        Logger.error("upsert_knowledge failed: #{inspect(err)}")
        {:error, err}
    end
  end

  @doc "Full-text search over the knowledge base. Returns [{path, snippet}]."
  def search_knowledge(query) do
    sql = """
    SELECT path,
           snippet(knowledge_fts, 1, '<b>', '</b>', '...', 20)
    FROM knowledge_fts
    WHERE content MATCH ?
    ORDER BY rank
    LIMIT 10
    """

    case Ecto.Adapters.SQL.query(__MODULE__, sql, [query]) do
      {:ok, %{rows: rows}} ->
        results = Enum.map(rows, fn [path, snippet] -> %{path: path, snippet: snippet} end)
        {:ok, results}

      {:error, err} ->
        Logger.error("search_knowledge failed: #{inspect(err)}")
        {:error, err}
    end
  end

  # -- FTS5: skills --

  @doc "Upsert a skill document into the skills FTS5 index."
  def upsert_skill_fts(skill_id, name, content) do
    sql = """
    INSERT INTO skills_fts (skill_id, name, content)
    VALUES (?, ?, ?)
    ON CONFLICT(skill_id) DO UPDATE SET
      name = excluded.name,
      content = excluded.content
    """

    case Ecto.Adapters.SQL.query(__MODULE__, sql, [skill_id, name, content]) do
      {:ok, _} -> :ok
      {:error, err} -> {:error, err}
    end
  end

  @doc "BM25 full-text search over skills. Returns [{skill_id, snippet}]."
  def search_skills_fts(query, limit \\ 10) do
    sql = """
    SELECT skill_id,
           snippet(skills_fts, 1, '<b>', '</b>', '...', 20)
    FROM skills_fts
    WHERE skills_fts MATCH ?
    ORDER BY rank
    LIMIT ?
    """

    case Ecto.Adapters.SQL.query(__MODULE__, sql, [query, limit]) do
      {:ok, %{rows: rows}} ->
        results = Enum.map(rows, fn [id, snippet] -> %{skill_id: id, snippet: snippet} end)
        {:ok, results}

      {:error, err} ->
        {:error, err}
    end
  end
end
