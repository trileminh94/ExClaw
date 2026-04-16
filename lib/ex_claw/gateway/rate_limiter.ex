defmodule ExClaw.Gateway.RateLimiter do
  @moduledoc """
  Per-IP ETS token-bucket rate limiter for WebSocket connections and HTTP requests.

  Each IP gets a bucket of `@capacity` tokens that refills at `@refill_rate`
  tokens per second. Each request consumes one token. When the bucket is empty
  the request is rejected with 429.

  State is stored in an ETS table owned by this GenServer. All checks are
  plain ETS reads/writes — no GenServer call overhead on the hot path.
  """
  use GenServer

  @table :gateway_rate_limiter
  # Max tokens per bucket
  @capacity 60
  # Tokens added per second
  @refill_rate 10
  # Cleanup buckets older than 5 minutes
  @cleanup_interval_ms 60_000

  # -- Client API --

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check and consume one token for the given IP string.

  Returns `:ok` (allowed) or `{:error, :rate_limited}`.
  """
  @spec check(String.t()) :: :ok | {:error, :rate_limited}
  def check(ip) when is_binary(ip) do
    now = System.monotonic_time(:second)

    case :ets.lookup(@table, ip) do
      [] ->
        # First request from this IP — create full bucket, consume one token
        :ets.insert(@table, {ip, @capacity - 1, now})
        :ok

      [{^ip, tokens, last_refill}] ->
        elapsed = now - last_refill
        refilled = min(@capacity, tokens + elapsed * @refill_rate)

        if refilled >= 1 do
          :ets.insert(@table, {ip, refilled - 1, now})
          :ok
        else
          {:error, :rate_limited}
        end
    end
  end

  # -- GenServer --

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cutoff = System.monotonic_time(:second) - 300
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", cutoff}], [true]}])
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end
end
