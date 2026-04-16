defmodule ExClaw.Store.ProviderStore do
  @moduledoc "Behaviour for LLM provider config persistence."

  @type provider_id :: String.t()
  @type provider :: map()
  @type attrs :: map()

  @callback create_provider(attrs()) :: {:ok, provider()} | {:error, term()}
  @callback get_provider(provider_id()) :: {:ok, provider()} | {:error, :not_found}
  @callback list_providers(tenant_id :: String.t() | nil) :: {:ok, [provider()]}
  @callback update_provider(provider_id(), attrs()) :: {:ok, provider()} | {:error, term()}
  @callback delete_provider(provider_id()) :: :ok | {:error, term()}
end
