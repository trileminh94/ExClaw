defmodule ExClaw.Crypto do
  @moduledoc """
  AES-256-GCM encrypt/decrypt for storing sensitive values (API keys, tokens).

  Master key source (first found wins):
  1. Application config `:ex_claw, :encryption_key`
  2. `EXCLAW_ENCRYPTION_KEY` environment variable
  3. Dev-only random key generated at startup (not suitable for production)
  """

  @aad "ExClaw-v1"

  @doc "Encrypt a plaintext string. Returns a Base64-encoded ciphertext."
  @spec encrypt(String.t()) :: {:ok, String.t()} | {:error, term()}
  def encrypt(plaintext) when is_binary(plaintext) do
    key = master_key()
    iv = :crypto.strong_rand_bytes(12)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, true)

    encoded = Base.encode64(iv <> tag <> ciphertext)
    {:ok, encoded}
  rescue
    e -> {:error, e}
  end

  @doc "Decrypt a Base64-encoded ciphertext. Returns the original plaintext."
  @spec decrypt(String.t()) :: {:ok, String.t()} | {:error, :invalid}
  def decrypt(encoded) when is_binary(encoded) do
    key = master_key()

    with {:ok, bin} <- Base.decode64(encoded),
         <<iv::binary-size(12), tag::binary-size(16), ciphertext::binary>> <- bin,
         plaintext when is_binary(plaintext) <-
           :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false) do
      {:ok, plaintext}
    else
      _ -> {:error, :invalid}
    end
  rescue
    _ -> {:error, :invalid}
  end

  # -- Private --

  defp master_key do
    raw =
      Application.get_env(:ex_claw, :encryption_key) ||
        System.get_env("EXCLAW_ENCRYPTION_KEY") ||
        dev_fallback_key()

    parse_key(raw)
  end

  defp parse_key(key) when byte_size(key) == 32, do: key

  defp parse_key(key) when is_binary(key) do
    cond do
      String.length(key) == 64 ->
        case Base.decode16(key, case: :mixed) do
          {:ok, bin} when byte_size(bin) == 32 -> bin
          _ -> derive_key(key)
        end

      true ->
        case Base.decode64(key) do
          {:ok, bin} when byte_size(bin) == 32 -> bin
          _ -> derive_key(key)
        end
    end
  end

  defp derive_key(raw) do
    :crypto.hash(:sha256, raw)
  end

  @dev_key_path ".exclaw_dev_key"

  defp dev_fallback_key do
    case File.read(@dev_key_path) do
      {:ok, key} ->
        key

      {:error, _} ->
        key = :crypto.strong_rand_bytes(32)
        File.write!(@dev_key_path, key)
        key
    end
  end
end
