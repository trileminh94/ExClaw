defmodule ExClaw.Application do
  @moduledoc """
  OTP Application entry point for ExClaw.

  Supervision tree:
  - Registry               — unique process registry for session GenServers
  - EventBus               — duplicate Registry for pub/sub
  - ExClaw.Repo            — Ecto SQLite3 repository
  - Tool.RateLimiter       — ETS token bucket for per-(tool,user) rate limits
  - Tool.Registry          — ETS-backed tool registry (registers all built-in tools)
  - Tool.Supervisor        — Task.Supervisor for isolated tool execution
  - Scheduler.Supervisor   — 4-lane concurrency control + per-session queues
  - Session.Supervisor     — DynamicSupervisor for Agent Actors
  - Watcher                — FileSystem watcher for FTS5 knowledge indexing
  - Bootstrap.FileRouter   — ETS cache of context files (SOUL.md, USER.md, etc.)
  - LLM.Pool               — NimblePool for rate-limited LLM API calls
  - Gateway.Supervisor     — Bandit HTTP + WebSocket server
  """
  use Application

  @impl true
  def start(_type, _args) do
    knowledge_path = Application.get_env(:ex_claw, :knowledge_path, "./knowledge")
    {provider_module, provider_config} = default_provider()

    children = [
      # Core registries
      {Registry, keys: :unique, name: ExClaw.Registry},
      ExClaw.EventBus,
      # Persistence
      ExClaw.Repo,
      # Tool subsystem (registry before supervisor, rate limiter before registry)
      ExClaw.Tool.RateLimiter,
      ExClaw.Tool.Registry,
      {ExClaw.Tool.Supervisor, []},
      # Scheduler (depends on Tool.Supervisor being up)
      ExClaw.Scheduler.Supervisor,
      # Session actors
      {ExClaw.Session.Supervisor, []},
      # Knowledge / context
      {ExClaw.Watcher, [path: knowledge_path]},
      {ExClaw.Bootstrap.FileRouter, []},
      # LLM connection pool
      {NimblePool,
       worker: {ExClaw.LLM.PoolWorker, {provider_module, provider_config}},
       name: ExClaw.LLM.Pool,
       pool_size: 5},
      # HTTP + WebSocket gateway (last — depends on everything above)
      ExClaw.Gateway.Supervisor
    ]

    opts = [strategy: :one_for_one, name: ExClaw.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # -- Private --

  defp default_provider do
    api_key = Application.get_env(:ex_claw, :api_key, "")
    model = Application.get_env(:ex_claw, :model, "claude-opus-4-6")

    module =
      case Application.get_env(:ex_claw, :llm_provider, :anthropic) do
        :anthropic -> ExClaw.LLM.Providers.Anthropic
        :openai -> ExClaw.LLM.Providers.OpenAI
        :dashscope -> ExClaw.LLM.Providers.DashScope
        mod when is_atom(mod) -> mod
      end

    config = %{api_key: api_key, model: model}
    {module, config}
  end
end
