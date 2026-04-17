defmodule ExClaw.Tool.Executor do
  @moduledoc """
  Central tool dispatcher — replaces the old Tool.Runner.

  For each tool call from the LLM:
  1. Look up the tool in Tool.Registry
  2. Check per-(tool, user) rate limit
  3. Run the implementation function
  4. Scrub credentials from the output
  5. Return the result string

  Multiple tool calls (parallel) are executed concurrently via Task.async_stream.
  The caller (Pipeline ToolStage) handles the dangerous-tool approval gate before
  calling this module.
  """

  require Logger

  alias ExClaw.Tool.{Registry, RateLimiter, Scrubber}

  @doc """
  Execute a list of tool calls concurrently.

  `calls` is a list of maps: `%{"name" => name, "input" => input, "id" => id}`
  `context` is a map with `:user_id`, `:agent_id`, `:tenant_id` for rate limiting
  and tool implementations.

  Returns a list of result maps:
    `%{"tool_use_id" => id, "content" => string_result}`
  """
  @spec execute_all([map()], map()) :: [map()]
  def execute_all(calls, context \\ %{}) when is_list(calls) do
    calls
    |> Task.async_stream(
      fn call -> {call["id"], execute_one(call, context)} end,
      max_concurrency: 10,
      timeout: 60_000,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, {id, {:ok, content}}} ->
        %{"tool_use_id" => id, "content" => Scrubber.scrub(content)}

      {:ok, {id, {:error, reason}}} ->
        %{"tool_use_id" => id, "content" => "Error: #{Scrubber.scrub(to_string(reason))}"}

      {:exit, :timeout} ->
        %{"tool_use_id" => "unknown", "content" => "Error: tool execution timed out"}
    end)
  end

  @doc """
  Execute a single tool call.

  Returns `{:ok, result_string}` or `{:error, reason}`.
  """
  @spec execute_one(map(), map()) :: {:ok, String.t()} | {:error, term()}
  def execute_one(%{"name" => name, "input" => input} = _call, context) do
    user_id = Map.get(context, :user_id, "anonymous")

    case Registry.lookup(name) do
      {:error, :not_found} ->
        {:error, "Unknown tool: #{name}"}

      {:ok, {meta, impl_module}} ->
        with :ok <- RateLimiter.check(name, user_id, meta.rate_limit) do
          Logger.debug("[Tool] executing #{name} for user=#{user_id}")
          apply(impl_module, :execute, [input, context])
        else
          {:error, :rate_limited} ->
            {:error, "Tool #{name} rate limit exceeded — try again in a moment"}
        end
    end
  end

  def execute_one(%{"name" => _name} = call, ctx) do
    execute_one(Map.put_new(call, "input", %{}), ctx)
  end
end
