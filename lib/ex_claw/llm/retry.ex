defmodule ExClaw.LLM.Retry do
  @moduledoc """
  Exponential-backoff retry wrapper for LLM calls.

  Retries on transient errors (rate limit 429, server error 5xx, network errors).
  Does not retry on client errors (4xx except 429) or successful responses.
  """
  require Logger

  @default_max_attempts 3
  @base_delay_ms 500

  @doc """
  Wrap a function with retry logic.

  Options:
    - `:max_attempts` — total attempts (default: 3)
    - `:base_delay_ms` — initial backoff delay in ms (default: 500)
  """
  @spec with_retry((() -> {:ok, term()} | {:error, term()}), keyword()) ::
          {:ok, term()} | {:error, term()}
  def with_retry(fun, opts \\ []) do
    max = Keyword.get(opts, :max_attempts, @default_max_attempts)
    base = Keyword.get(opts, :base_delay_ms, @base_delay_ms)
    attempt(fun, 1, max, base)
  end

  defp attempt(fun, attempt, max, base) do
    case fun.() do
      {:ok, _} = ok ->
        ok

      {:error, reason} = err ->
        if attempt < max and retryable?(reason) do
          delay = base * :math.pow(2, attempt - 1) |> round()
          Logger.warning("[Retry] attempt #{attempt}/#{max} failed: #{inspect(reason)} — retrying in #{delay}ms")
          Process.sleep(delay)
          attempt(fun, attempt + 1, max, base)
        else
          err
        end
    end
  end

  defp retryable?({:api_error, status, _}) when status in [429, 500, 502, 503, 504], do: true
  defp retryable?(%{reason: reason}) when reason in [:timeout, :econnrefused, :closed], do: true
  defp retryable?(_), do: false
end
