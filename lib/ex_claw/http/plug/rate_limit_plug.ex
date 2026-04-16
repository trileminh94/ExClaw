defmodule ExClaw.HTTP.Plug.RateLimitPlug do
  @moduledoc "HTTP rate limiter plug — delegates to Gateway.RateLimiter."

  import Plug.Conn
  alias ExClaw.Gateway.RateLimiter

  def init(opts), do: opts

  def call(conn, _opts) do
    ip = remote_ip(conn)

    case RateLimiter.check(ip) do
      :ok ->
        conn

      {:error, :rate_limited} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, ~s({"error":"rate limit exceeded"}))
        |> halt()
    end
  end

  defp remote_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end
end
