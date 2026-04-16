defmodule ExClaw.Scheduler.AdaptiveThrottle do
  @moduledoc """
  Adaptive concurrency throttle based on LLM context window usage.

  When a session's context token usage exceeds the high-water mark (60%),
  the lane cap for that session's queue is reduced to 1 — effectively
  serializing all requests to prevent context explosion.

  Usage (called from PruneStage when token utilization is high):
      AdaptiveThrottle.set_throttled(session_id, true)

  The throttle state is stored in an ETS table owned by this GenServer.
  Reads are concurrent direct ETS lookups.
  """
  use GenServer

  @table :adaptive_throttle
  # % of context_window that triggers throttling
  @high_water_pct 0.6

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns true if the given session should be throttled to lane cap=1."
  @spec throttled?(String.t()) :: boolean()
  def throttled?(session_id) do
    case :ets.lookup(@table, session_id) do
      [{^session_id, true}] -> true
      _ -> false
    end
  end

  @doc "Set or clear the throttle flag for a session."
  @spec set_throttled(String.t(), boolean()) :: :ok
  def set_throttled(session_id, flag) when is_boolean(flag) do
    if flag do
      :ets.insert(@table, {session_id, true})
    else
      :ets.delete(@table, session_id)
    end
    :ok
  end

  @doc """
  Check token usage and automatically set the throttle flag.

  Called by PruneStage with current token count and context window size.
  """
  @spec check_usage(String.t(), non_neg_integer(), non_neg_integer()) :: :ok
  def check_usage(session_id, used_tokens, context_window) when context_window > 0 do
    pct = used_tokens / context_window
    set_throttled(session_id, pct >= @high_water_pct)
  end

  def check_usage(_session_id, _used, 0), do: :ok

  @doc "Returns the high-water percentage threshold."
  def high_water_pct, do: @high_water_pct

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set,
      read_concurrency: true, write_concurrency: true])
    {:ok, %{}}
  end
end
