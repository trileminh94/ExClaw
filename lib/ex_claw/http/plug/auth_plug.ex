defmodule ExClaw.HTTP.Plug.AuthPlug do
  @moduledoc """
  Extracts and validates the Bearer token from HTTP requests.

  On success, assigns `conn.assigns.auth` to an `%Auth.Context{}`.
  On failure, halts the connection with 401 JSON.
  """

  import Plug.Conn
  alias ExClaw.Auth.TokenAuth

  def init(opts), do: opts

  def call(conn, _opts) do
    token = extract_token(conn)

    case TokenAuth.authenticate(token) do
      {:ok, auth} ->
        assign(conn, :auth, auth)

      {:error, :unauthorized} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, ~s({"error":"unauthorized"}))
        |> halt()
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token | _] -> String.trim(token)
      ["bearer " <> token | _] -> String.trim(token)
      _ -> nil
    end
  end
end
