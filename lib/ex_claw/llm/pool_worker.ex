defmodule ExClaw.LLM.PoolWorker do
  @moduledoc """
  NimblePool worker that holds a provider-specific Req client.

  Pool state is `{provider_module, config}`. Each worker calls
  `provider_module.build_client(config)` to create its Req client.
  Checkouts yield the Req client; the caller passes it to the provider.
  """
  @behaviour NimblePool

  @impl NimblePool
  def init_worker({provider_module, config} = pool_state) do
    client = provider_module.build_client(config)
    {:ok, client, pool_state}
  end

  @impl NimblePool
  def handle_checkout(:checkout, _from, client, pool_state) do
    {:ok, client, client, pool_state}
  end

  @impl NimblePool
  def handle_checkin(_client_state, _from, client, pool_state) do
    {:ok, client, pool_state}
  end

  @impl NimblePool
  def terminate_worker(_reason, _client, pool_state) do
    {:ok, pool_state}
  end
end
