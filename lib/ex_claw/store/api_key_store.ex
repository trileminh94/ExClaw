defmodule ExClaw.Store.APIKeyStore do
  @moduledoc "Behaviour for API key persistence."

  @type key_id :: String.t()
  @type attrs :: map()

  @callback create_key(attrs()) :: {:ok, map()} | {:error, term()}
  @callback get_key_by_hash(hash :: String.t()) :: {:ok, map()} | {:error, :not_found}
  @callback list_keys(user_id :: String.t()) :: {:ok, [map()]}
  @callback update_key(key_id(), attrs()) :: {:ok, map()} | {:error, term()}
  @callback delete_key(key_id()) :: :ok | {:error, term()}
  @callback touch_last_used(key_id()) :: :ok
end
