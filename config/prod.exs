import Config

config :ex_claw,
  gateway_port: String.to_integer(System.get_env("EXCLAW_PORT", "8080"))
