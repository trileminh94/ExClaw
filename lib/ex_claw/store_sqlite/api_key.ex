defmodule ExClaw.StoreSQLite.APIKey do
  @moduledoc "SQLite implementation of ExClaw.Store.APIKeyStore."
  @behaviour ExClaw.Store.APIKeyStore

  import Ecto.Query
  alias ExClaw.Repo
  alias ExClaw.Store.Schema.APIKey

  @impl true
  def create_key(attrs) do
    %APIKey{} |> APIKey.changeset(attrs) |> Repo.insert() |> result()
  end

  @impl true
  def get_key_by_hash(hash) do
    case Repo.get_by(APIKey, key_hash: hash) do
      nil -> {:error, :not_found}
      k -> {:ok, k}
    end
  end

  @impl true
  def list_keys(user_id) do
    keys =
      from(k in APIKey,
        where: k.user_id == ^user_id,
        order_by: [desc: k.inserted_at]
      )
      |> Repo.all()

    {:ok, keys}
  end

  @impl true
  def update_key(id, attrs) do
    case Repo.get(APIKey, id) do
      nil -> {:error, :not_found}
      k -> k |> APIKey.changeset(attrs) |> Repo.update() |> result()
    end
  end

  @impl true
  def delete_key(id) do
    case Repo.get(APIKey, id) do
      nil -> {:error, :not_found}
      k -> Repo.delete(k) |> delete_result()
    end
  end

  @impl true
  def touch_last_used(id) do
    from(k in APIKey, where: k.id == ^id)
    |> Repo.update_all(set: [last_used_at: DateTime.utc_now()])

    :ok
  end

  defp result({:ok, struct}), do: {:ok, struct}
  defp result({:error, changeset}), do: {:error, changeset}

  defp delete_result({:ok, _}), do: :ok
  defp delete_result({:error, reason}), do: {:error, reason}
end
