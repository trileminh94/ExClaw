defmodule ExClaw.StoreSQLite.Memory do
  @moduledoc "SQLite implementation of ExClaw.Store.MemoryStore."
  @behaviour ExClaw.Store.MemoryStore

  import Ecto.Query
  alias ExClaw.Repo
  alias ExClaw.Store.Schema.MemoryDocument

  @impl true
  def create_document(attrs) do
    %MemoryDocument{} |> MemoryDocument.changeset(attrs) |> Repo.insert() |> result()
  end

  @impl true
  def get_document(id) do
    case Repo.get(MemoryDocument, id) do
      nil -> {:error, :not_found}
      d -> {:ok, d}
    end
  end

  @impl true
  def list_documents(agent_id, user_id) do
    docs =
      from(d in MemoryDocument,
        where: d.agent_id == ^agent_id and d.user_id == ^user_id,
        order_by: [desc: d.inserted_at]
      )
      |> Repo.all()

    {:ok, docs}
  end

  @impl true
  def update_document(id, attrs) do
    case Repo.get(MemoryDocument, id) do
      nil -> {:error, :not_found}
      d -> d |> MemoryDocument.changeset(attrs) |> Repo.update() |> result()
    end
  end

  @impl true
  def delete_document(id) do
    case Repo.get(MemoryDocument, id) do
      nil -> {:error, :not_found}
      d -> Repo.delete(d) |> delete_result()
    end
  end

  @impl true
  def search_documents(query, opts) do
    # Phase 5 will add hybrid FTS+vector search.
    # For now, simple LIKE-based fallback.
    agent_id = Map.get(opts, :agent_id)
    user_id = Map.get(opts, :user_id)
    limit = Map.get(opts, :limit, 10)
    like = "%#{query}%"

    q =
      from(d in MemoryDocument,
        where: ilike(d.content, ^like) or ilike(d.summary, ^like),
        order_by: [desc: d.inserted_at],
        limit: ^limit
      )

    q =
      if agent_id, do: from(d in q, where: d.agent_id == ^agent_id), else: q

    q =
      if user_id, do: from(d in q, where: d.user_id == ^user_id), else: q

    {:ok, Repo.all(q)}
  end

  defp result({:ok, struct}), do: {:ok, struct}
  defp result({:error, changeset}), do: {:error, changeset}

  defp delete_result({:ok, _}), do: :ok
  defp delete_result({:error, reason}), do: {:error, reason}
end
