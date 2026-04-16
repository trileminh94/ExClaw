defmodule ExClaw.StoreSQLite.Skill do
  @moduledoc "SQLite implementation of ExClaw.Store.SkillStore."
  @behaviour ExClaw.Store.SkillStore

  import Ecto.Query
  alias ExClaw.Repo
  alias ExClaw.Store.Schema.Skill

  @impl true
  def create_skill(attrs) do
    %Skill{} |> Skill.changeset(attrs) |> Repo.insert() |> result()
  end

  @impl true
  def get_skill(id) do
    case Repo.get(Skill, id) do
      nil -> {:error, :not_found}
      s -> {:ok, s}
    end
  end

  @impl true
  def list_skills(opts) do
    query = from(s in Skill, order_by: [asc: s.tier, asc: s.name])

    query =
      case Map.get(opts, :tier) do
        nil -> query
        tier -> from(s in query, where: s.tier == ^tier)
      end

    query =
      case Map.get(opts, :agent_id) do
        nil -> query
        aid -> from(s in query, where: s.agent_id == ^aid)
      end

    {:ok, Repo.all(query)}
  end

  @impl true
  def update_skill(id, attrs) do
    case Repo.get(Skill, id) do
      nil -> {:error, :not_found}
      s -> s |> Skill.changeset(attrs) |> Repo.update() |> result()
    end
  end

  @impl true
  def delete_skill(id) do
    case Repo.get(Skill, id) do
      nil -> {:error, :not_found}
      s -> Repo.delete(s) |> delete_result()
    end
  end

  @impl true
  def search_skills(query_str, opts) do
    # Phase 5 will add BM25 FTS search via skills_fts virtual table.
    limit = Map.get(opts, :limit, 10)
    like = "%#{query_str}%"

    q =
      from(s in Skill,
        where: ilike(s.name, ^like) or ilike(s.content, ^like),
        order_by: [asc: s.tier, asc: s.name],
        limit: ^limit
      )

    {:ok, Repo.all(q)}
  end

  defp result({:ok, struct}), do: {:ok, struct}
  defp result({:error, changeset}), do: {:error, changeset}

  defp delete_result({:ok, _}), do: :ok
  defp delete_result({:error, reason}), do: {:error, reason}
end
