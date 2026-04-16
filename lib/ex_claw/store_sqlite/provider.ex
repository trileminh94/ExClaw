defmodule ExClaw.StoreSQLite.Provider do
  @moduledoc "SQLite implementation of ExClaw.Store.ProviderStore."
  @behaviour ExClaw.Store.ProviderStore

  import Ecto.Query
  alias ExClaw.Repo
  alias ExClaw.Store.Schema.Provider

  @impl true
  def create_provider(attrs) do
    %Provider{}
    |> Provider.changeset(attrs)
    |> Repo.insert()
    |> result()
  end

  @impl true
  def get_provider(id) do
    case Repo.get(Provider, id) do
      nil -> {:error, :not_found}
      p -> {:ok, p}
    end
  end

  @impl true
  def list_providers(tenant_id) do
    query =
      if tenant_id do
        from(p in Provider, where: p.tenant_id == ^tenant_id or is_nil(p.tenant_id))
      else
        from(p in Provider, where: is_nil(p.tenant_id))
      end

    {:ok, Repo.all(from(p in query, order_by: [asc: p.name]))}
  end

  @impl true
  def update_provider(id, attrs) do
    case Repo.get(Provider, id) do
      nil -> {:error, :not_found}
      p -> p |> Provider.changeset(attrs) |> Repo.update() |> result()
    end
  end

  @impl true
  def delete_provider(id) do
    case Repo.get(Provider, id) do
      nil -> {:error, :not_found}
      p -> Repo.delete(p) |> delete_result()
    end
  end

  defp result({:ok, struct}), do: {:ok, struct}
  defp result({:error, changeset}), do: {:error, changeset}

  defp delete_result({:ok, _}), do: :ok
  defp delete_result({:error, reason}), do: {:error, reason}
end
