defmodule ExClaw.Auth.TokenAuth do
  @moduledoc """
  Bearer-token authentication.

  Tokens are SHA-256-hashed before storage. On each request the incoming
  token is hashed and compared against `key_hash` in the `api_keys` table
  via StoreSQLite.APIKey.

  A dev gateway token shortcut (EXCLAW_GATEWAY_TOKEN env var) is checked
  first via constant-time comparison to avoid timing attacks.
  """

  alias ExClaw.Auth.Context
  alias ExClaw.StoreSQLite.APIKey

  @doc """
  Authenticates a Bearer token string.

  Returns `{:ok, %Auth.Context{}}` on success or `{:error, :unauthorized}`.
  """
  @spec authenticate(String.t()) :: {:ok, Context.t()} | {:error, :unauthorized}
  def authenticate(token) when is_binary(token) and token != "" do
    dev_token = Application.get_env(:ex_claw, :gateway_token, "dev-token")

    if Plug.Crypto.secure_compare(token, dev_token) do
      {:ok, %Context{user_id: "system", tenant_id: "default", role: :admin}}
    else
      lookup_api_key(token)
    end
  end

  def authenticate(_), do: {:error, :unauthorized}

  # -- Private --

  defp lookup_api_key(token) do
    hash = hash_token(token)

    case APIKey.get_key_by_hash(hash) do
      {:ok, key} ->
        # Fire-and-forget last_used update; ignore result
        Task.start(fn -> APIKey.touch_last_used(key.id) end)
        role = parse_role(key.role)
        {:ok, %Context{user_id: key.user_id, tenant_id: key.tenant_id, role: role}}

      {:error, _} ->
        {:error, :unauthorized}
    end
  end

  @doc "Returns the SHA-256 hex digest of a raw API token."
  def hash_token(token) do
    :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
  end

  defp parse_role("admin"),    do: :admin
  defp parse_role("operator"), do: :operator
  defp parse_role(_),          do: :viewer
end
