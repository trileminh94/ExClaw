defmodule ExClaw.StoreSQLite.Message do
  @moduledoc "SQLite implementation of ExClaw.Store.MessageStore."
  @behaviour ExClaw.Store.MessageStore

  import Ecto.Query
  alias ExClaw.Repo
  alias ExClaw.Store.Schema.Message

  @impl true
  def append_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> result()
  end

  @impl true
  def list_messages(session_id, opts) do
    limit = Map.get(opts, :limit, 100)

    messages =
      from(m in Message,
        where: m.session_id == ^session_id,
        order_by: [asc: m.inserted_at],
        limit: ^limit
      )
      |> Repo.all()

    {:ok, messages}
  end

  @impl true
  def delete_messages(session_id) do
    from(m in Message, where: m.session_id == ^session_id)
    |> Repo.delete_all()

    :ok
  end

  defp result({:ok, struct}), do: {:ok, struct}
  defp result({:error, changeset}), do: {:error, changeset}
end
