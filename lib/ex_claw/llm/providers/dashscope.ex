defmodule ExClaw.LLM.Providers.DashScope do
  @moduledoc """
  Alibaba DashScope provider.
  DashScope uses an OpenAI-compatible API, so this is a thin wrapper over OpenAI.
  Implements ExClaw.LLM.Provider behaviour.
  """
  @behaviour ExClaw.LLM.Provider

  alias ExClaw.LLM.Providers.OpenAI

  @api_base "https://dashscope.aliyuncs.com/compatible-mode"

  @impl true
  def name, do: "dashscope"

  @impl true
  def default_model, do: "qwen-max"

  @impl true
  def build_client(config) do
    config
    |> Map.put_new(:base_url, @api_base)
    |> OpenAI.build_client()
  end

  @impl true
  defdelegate chat(client, request), to: OpenAI

  @impl true
  defdelegate chat_stream(client, request, stream_pid), to: OpenAI
end
