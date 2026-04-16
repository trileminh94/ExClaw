import Config

config :ex_claw,
  llm_provider: :anthropic,
  api_key: System.get_env("ANTHROPIC_API_KEY"),
  model: "claude-opus-4-6",
  knowledge_path: "./knowledge",
  safe_tools: ["ls", "cat", "grep", "search_local_docs", "read_file"],
  dangerous_tools: ["rm", "bash", "curl"]

config :ex_claw,
  gateway_port: 8080,
  gateway_token: System.get_env("EXCLAW_GATEWAY_TOKEN", "dev-token")

config :ex_claw, ecto_repos: [ExClaw.Repo]

config :ex_claw, ExClaw.Repo,
  database: "data/ex_claw.db",
  pool_size: 5,
  # UUIDs stored as text strings
  migration_primary_key: [name: :id, type: :binary_id]
