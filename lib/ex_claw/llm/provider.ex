defmodule ExClaw.LLM.Provider do
  @moduledoc """
  Behaviour every LLM provider must implement.

  Design notes:
  - `build_client/1` creates a Req.Request base client from provider config.
    This is called once per NimblePool worker at pool init time.
  - `chat/2` and `chat_stream/3` receive the Req client from the pool.
    Pool checkout is handled externally (in ThinkStage).
  - `name/0` returns a string identifier (e.g. "anthropic", "openai").
  - `default_model/0` returns the model name to use when none specified in config.
  """

  alias ExClaw.LLM.{Request, Response}

  @type client :: Req.Request.t()
  @type config :: map()

  @doc "Short identifier for this provider (e.g. \"anthropic\")."
  @callback name() :: String.t()

  @doc "Default model name for this provider."
  @callback default_model() :: String.t()

  @doc "Build a Req base client from provider config (called at pool init)."
  @callback build_client(config()) :: client()

  @doc "Blocking chat call. Returns full Response."
  @callback chat(client(), Request.t()) :: {:ok, Response.t()} | {:error, term()}

  @doc """
  Streaming chat call. Sends %StreamChunk{} messages to stream_pid as tokens arrive.
  Returns {:ok, Response.t()} with the full final response when done.
  """
  @callback chat_stream(client(), Request.t(), stream_pid :: pid()) ::
              {:ok, Response.t()} | {:error, term()}
end
