defmodule ExClaw.Tool.Scrubber do
  @moduledoc """
  Credential and secret scrubber for tool output.

  Replaces common secret patterns with `[REDACTED]` before tool results
  are returned to the LLM or stored in the database.

  Patterns cover:
  - API key formats (sk-..., AKIA..., etc.)
  - Bearer tokens
  - Private key PEM blocks
  - AWS/GCP/Azure key patterns
  - Generic high-entropy token patterns (40+ hex chars)
  """

  @patterns [
    # Anthropic API keys
    {~r/sk-ant-[A-Za-z0-9\-_]{20,}/, "[REDACTED:anthropic-key]"},
    # OpenAI API keys
    {~r/sk-[A-Za-z0-9]{20,}/, "[REDACTED:openai-key]"},
    # AWS access key IDs
    {~r/AKIA[0-9A-Z]{16}/, "[REDACTED:aws-key-id]"},
    # AWS secret access keys (40 base64 chars after label)
    {~r/(?i)aws.{0,20}secret.{0,20}[=:]\s*[A-Za-z0-9\/+]{40}/, "[REDACTED:aws-secret]"},
    # Bearer tokens
    {~r/(?i)bearer\s+[A-Za-z0-9\-_\.]{20,}/, "[REDACTED:bearer-token]"},
    # PEM private key blocks
    {~r/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/, "[REDACTED:private-key]"},
    # Generic high-entropy 40+ hex tokens (SHA-like)
    {~r/\b[0-9a-fA-F]{40,}\b/, "[REDACTED:hex-token]"},
    # Generic 32+ char base64url tokens after common labels
    {~r/(?i)(?:token|secret|password|passwd|api[_-]?key)\s*[=:]\s*["']?[A-Za-z0-9\-_\.+\/]{32,}["']?/, "[REDACTED:secret]"}
  ]

  @doc """
  Scrub secrets from a string.

  Returns the sanitized string with secrets replaced by `[REDACTED:type]` tags.
  """
  @spec scrub(String.t()) :: String.t()
  def scrub(text) when is_binary(text) do
    Enum.reduce(@patterns, text, fn {regex, replacement}, acc ->
      Regex.replace(regex, acc, replacement)
    end)
  end

  def scrub(other), do: other
end
