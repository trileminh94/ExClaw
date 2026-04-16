defmodule ExClaw.Tool.RateLimiter do
  @moduledoc """
  Per-(tool_name, user_id) ETS token-bucket rate limiter.

  Used by Tool.Executor to enforce per-tool call limits.
  Bucket state is keyed by `{tool_name, user_id}`.
  Refill rate: 1 token per second (up to each tool's `rate_limit` cap).

  This GenServer owns the ETS table; all bucket checks are direct ETS
  reads+writes (no call overhead on the hot path).
  """
  use GenServer

  @table :tool_rate_limiter
  @cleanup_interval_ms 120_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check and consume one token for `{tool_name, user_id}`.

  `limit` is the maximum tokens (from Tool.Metadata.rate_limit).
  Returns `:ok` or `{:error, :rate_limited}`.
  """
  @spec check(String.t(), String.t(), pos_integer()) :: :ok | {:error, :rate_limited}
  def check(tool_name, user_id, limit) when is_integer(limit) and limit > 0 do
    key = {tool_name, user_id}
    now = System.monotonic_time(:second)

    case :ets.lookup(@table, key) do
      [] ->
        :ets.insert(@table, {key, limit - 1, now})
        :ok

      [{^key, tokens, last_refill}] ->
        elapsed = now - last_refill
        refilled = min(limit, tokens + elapsed)

        if refilled >= 1 do
          :ets.insert(@table, {key, refilled - 1, now})
          :ok
        else
          {:error, :rate_limited}
        end
    end
  end

  # nil rate_limit = unlimited
  def check(_tool_name, _user_id, nil), do: :ok

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set,
      read_concurrency: true, write_concurrency: true])
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cutoff = System.monotonic_time(:second) - 300
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", cutoff}], [true]}])
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
    {:noreply, state}
  end
end
