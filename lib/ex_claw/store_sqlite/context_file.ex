defmodule ExClaw.StoreSQLite.ContextFile do
  @moduledoc "SQLite implementation of ExClaw.Store.ContextFileStore."
  @behaviour ExClaw.Store.ContextFileStore

  import Ecto.Query
  alias ExClaw.Repo
  alias ExClaw.Store.Schema.{AgentContextFile, UserContextFile}

  @impl true
  def get_agent_file(agent_id, filename) do
    case Repo.get_by(AgentContextFile, agent_id: agent_id, filename: filename) do
      nil -> {:error, :not_found}
      f -> {:ok, f.content}
    end
  end

  @impl true
  def get_user_file(agent_id, user_id, filename) do
    case Repo.get_by(UserContextFile, agent_id: agent_id, user_id: user_id, filename: filename) do
      nil -> {:error, :not_found}
      f -> {:ok, f.content}
    end
  end

  @impl true
  def upsert_agent_file(%{agent_id: agent_id, filename: filename, content: content}) do
    case Repo.get_by(AgentContextFile, agent_id: agent_id, filename: filename) do
      nil ->
        %AgentContextFile{}
        |> AgentContextFile.changeset(%{agent_id: agent_id, filename: filename, content: content})
        |> Repo.insert()
        |> upsert_result()

      existing ->
        existing
        |> AgentContextFile.changeset(%{content: content})
        |> Repo.update()
        |> upsert_result()
    end
  end

  @impl true
  def upsert_user_file(%{agent_id: agent_id, user_id: user_id, filename: filename, content: content}) do
    case Repo.get_by(UserContextFile, agent_id: agent_id, user_id: user_id, filename: filename) do
      nil ->
        %UserContextFile{}
        |> UserContextFile.changeset(%{
          agent_id: agent_id,
          user_id: user_id,
          filename: filename,
          content: content
        })
        |> Repo.insert()
        |> upsert_result()

      existing ->
        existing
        |> UserContextFile.changeset(%{content: content})
        |> Repo.update()
        |> upsert_result()
    end
  end

  @impl true
  def list_agent_files(agent_id) do
    files =
      from(f in AgentContextFile,
        where: f.agent_id == ^agent_id,
        order_by: [asc: f.filename]
      )
      |> Repo.all()

    {:ok, files}
  end

  @impl true
  def list_user_files(agent_id, user_id) do
    files =
      from(f in UserContextFile,
        where: f.agent_id == ^agent_id and f.user_id == ^user_id,
        order_by: [asc: f.filename]
      )
      |> Repo.all()

    {:ok, files}
  end

  @impl true
  def delete_agent_file(agent_id, filename) do
    case Repo.get_by(AgentContextFile, agent_id: agent_id, filename: filename) do
      nil -> {:error, :not_found}
      f -> Repo.delete(f) |> delete_result()
    end
  end

  defp upsert_result({:ok, _}), do: :ok
  defp upsert_result({:error, changeset}), do: {:error, changeset}

  defp delete_result({:ok, _}), do: :ok
  defp delete_result({:error, reason}), do: {:error, reason}
end
