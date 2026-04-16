defmodule ExClaw.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_claw,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ExClaw.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:ecto_sqlite3, "~> 0.17"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.19", optional: true},
      {:bandit, "~> 1.6"},
      {:websock, "~> 0.5"},
      {:websock_adapter, "~> 0.5"},
      {:plug, "~> 1.16"},
      {:plug_crypto, "~> 2.1"},
      {:muontrap, "~> 1.5"},
      {:file_system, "~> 1.0"},
      {:nimble_pool, "~> 1.1"},
      {:jason, "~> 1.4"}
    ]
  end
end
