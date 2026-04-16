defmodule ExClaw.StoreSQLite.Session do
  @moduledoc "SQLite implementation of ExClaw.Store.SessionStore."
  @behaviour ExClaw.Store.SessionStore

  import Ecto.Query
  alias ExClaw.Repo
  alias ExClaw.Store.Schema.Session
  alias ExClaw.Store.Schema.Message

  @impl true
  def create_session(attrs) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
    |> result()
  end

  @impl true
  def get_session(id) do
    case Repo.get(Session, id) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  @impl true
  def list_sessions(user_id) do
    sessions =
      from(s in Session,
        where: s.user_id == ^user_id,
        order_by: [desc: s.inserted_at]
      )
      |> Repo.all()

    {:ok, sessions}
  end

  @impl true
  def update_session(id, attrs) do
    case Repo.get(Session, id) do
      nil ->
        {:error, :not_found}

      session ->
        session
        |> Session.changeset(attrs)
        |> Repo.update()
        |> result()
    end
  end

  @impl true
  def delete_session(id) do
    case Repo.get(Session, id) do
      nil -> {:error, :not_found}
      session -> Repo.delete(session) |> delete_result()
    end
  end

  @impl true
  def hydrate_messages(session_id, limit) do
    messages =
      from(m in Message,
        where: m.session_id == ^session_id,
        order_by: [asc: m.inserted_at],
        limit: ^limit
      )
      |> Repo.all()
      |> Enum.map(&to_message_map/1)

    {:ok, messages}
  end

  # -- Private --

  defp to_message_map(m) do
    %{
      id: m.id,
      role: m.role,
      content: m.content,
      tool_calls: m.tool_calls,
      tool_results: m.tool_results,
      thinking: m.thinking
    }
  end

  defp result({:ok, struct}), do: {:ok, struct}
  defp result({:error, changeset}), do: {:error, changeset}

  defp delete_result({:ok, _}), do: :ok
  defp delete_result({:error, reason}), do: {:error, reason}
end
