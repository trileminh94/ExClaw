defmodule ExClaw.Gateway.Supervisor do
  @moduledoc """
  Supervises the Bandit HTTP/WebSocket server and supporting gateway processes.

  Children:
  - RateLimiter — ETS-backed token bucket (must start before Bandit)
  - Bandit      — HTTP + WebSocket server on configured port
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    port = Application.get_env(:ex_claw, :gateway_port, 8080)

    children = [
      ExClaw.Gateway.RateLimiter,
      {Bandit,
       plug: ExClaw.HTTP.Router,
       port: port,
       websocket_enabled: true,
       http: []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
