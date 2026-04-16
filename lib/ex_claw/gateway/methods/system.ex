defmodule ExClaw.Gateway.Methods.System do
  @moduledoc """
  WebSocket method handlers for system/meta operations.

  Methods:
  - `system.info`   — runtime information (version, uptime, memory)
  - `system.health` — simple health check (always succeeds if authenticated)
  """

  alias ExClaw.Auth.{Context, RBAC}

  def handle(method, params, %Context{} = auth) do
    case method do
      "system.info"   -> info(params, auth)
      "system.health" -> health(auth)
      _               -> {:error, 404, "method not found"}
    end
  end

  defp info(_params, auth) do
    with :ok <- RBAC.check_permission(auth, :system_info) do
      mem = :erlang.memory()
      {:ok, %{
        app: "ex_claw",
        version: Application.spec(:ex_claw, :vsn) |> to_string(),
        uptime_seconds: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000),
        memory: %{
          total: mem[:total],
          processes: mem[:processes],
          binary: mem[:binary]
        },
        scheduler_count: :erlang.system_info(:schedulers_online)
      }}
    else
      {:error, :forbidden} -> {:error, 403, "forbidden"}
    end
  end

  defp health(auth) do
    with :ok <- RBAC.check_permission(auth, :system_info) do
      {:ok, %{status: "ok"}}
    else
      {:error, :forbidden} -> {:error, 403, "forbidden"}
    end
  end
end
