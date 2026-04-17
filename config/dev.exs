import Config

# Use a non-conflicting port in dev (Docker commonly uses 8080)
config :ex_claw,
  gateway_port: String.to_integer(System.get_env("EXCLAW_PORT", "18080"))
