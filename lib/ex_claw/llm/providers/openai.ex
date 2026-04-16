defmodule ExClaw.LLM.Providers.OpenAI do
  @moduledoc """
  OpenAI-compatible provider.
  Works with OpenAI, Groq, Together AI, local Ollama, etc.
  Implements ExClaw.LLM.Provider behaviour.
  """
  @behaviour ExClaw.LLM.Provider

  require Logger
  alias ExClaw.LLM.{Request, Response, StreamChunk, SSEReader}

  @api_base "https://api.openai.com"

  @impl true
  def name, do: "openai"

  @impl true
  def default_model, do: "gpt-4o"

  @impl true
  def build_client(config) do
    api_key = Map.get(config, :api_key, "")

    Req.new(
      base_url: Map.get(config, :base_url, @api_base),
      headers: [
        {"authorization", "Bearer #{api_key}"},
        {"content-type", "application/json"}
      ],
      receive_timeout: 120_000
    )
  end

  @impl true
  def chat(client, %Request{} = req) do
    body = build_body(req, false)

    case Req.post(client, url: "/v1/chat/completions", json: body) do
      {:ok, %{status: 200, body: response}} ->
        {:ok, parse_response(response)}

      {:ok, %{status: 429, body: body}} ->
        {:error, {:api_error, 429, body}}

      {:ok, %{status: status, body: body}} ->
        Logger.error("[OpenAI] API error #{status}: #{inspect(body)}")
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error("[OpenAI] Request error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def chat_stream(client, %Request{} = req, stream_pid) do
    body = build_body(req, true)

    case Req.post(client, url: "/v1/chat/completions", json: body) do
      {:ok, %{status: 200, body: raw_body}} ->
        response = stream_parse(raw_body, stream_pid)
        send(stream_pid, StreamChunk.done(response))
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        send(stream_pid, StreamChunk.error({:api_error, status, body}))
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        send(stream_pid, StreamChunk.error(reason))
        {:error, reason}
    end
  end

  # -- Private --

  defp build_body(%Request{} = req, stream) do
    body = %{
      model: req.model || default_model(),
      max_tokens: req.max_tokens,
      messages: format_messages(req.messages, req.system),
      stream: stream
    }

    body = if req.tools != [], do: Map.put(body, :tools, openai_tools(req.tools)), else: body
    body = if req.temperature, do: Map.put(body, :temperature, req.temperature), else: body
    body
  end

  defp format_messages(messages, system) do
    system_msg = if system, do: [%{role: "system", content: system}], else: []

    content_msgs =
      Enum.flat_map(messages, fn msg ->
        case msg do
          %{role: "tool", content: content, name: name} ->
            [%{role: "tool", content: content || "", tool_call_id: name}]

          %{tool_calls: tool_calls} when is_list(tool_calls) ->
            calls =
              Enum.map(tool_calls, fn tc ->
                %{
                  id: tc["id"] || "call_#{:erlang.unique_integer([:positive])}",
                  type: "function",
                  function: %{name: tc["name"], arguments: Jason.encode!(tc["input"] || %{})}
                }
              end)

            [%{role: "assistant", content: nil, tool_calls: calls}]

          %{role: "system"} ->
            []

          %{role: role, content: content} when not is_nil(content) ->
            [%{role: to_string(role), content: content}]

          _ ->
            []
        end
      end)

    system_msg ++ content_msgs
  end

  defp openai_tools(tools) do
    Enum.map(tools, fn tool ->
      %{
        type: "function",
        function: %{
          name: tool[:name] || tool["name"],
          description: tool[:description] || tool["description"],
          parameters: tool[:input_schema] || tool["input_schema"] || %{type: "object", properties: %{}}
        }
      }
    end)
  end

  defp parse_response(%{"choices" => [%{"message" => msg} | _]} = raw) do
    usage = raw["usage"] || %{}
    content = msg["content"]
    tool_calls_raw = msg["tool_calls"]

    tool_calls =
      if tool_calls_raw do
        Enum.map(tool_calls_raw, fn tc ->
          fn_data = tc["function"] || %{}
          input = case Jason.decode(fn_data["arguments"] || "{}") do
            {:ok, map} -> map
            _ -> %{}
          end
          %{"id" => tc["id"], "name" => fn_data["name"], "input" => input}
        end)
      else
        nil
      end

    %Response{
      content: content,
      tool_calls: tool_calls,
      model: raw["model"],
      stop_reason: get_in(raw, ["choices", Access.at(0), "finish_reason"]),
      usage: %{
        prompt_tokens: usage["prompt_tokens"] || 0,
        completion_tokens: usage["completion_tokens"] || 0
      }
    }
  end

  defp parse_response(body) do
    Logger.error("[OpenAI] Unexpected response: #{inspect(body)}")
    %Response{}
  end

  defp stream_parse(raw_body, stream_pid) when is_binary(raw_body) do
    {text, tool_calls, usage, stop_reason, model} =
      raw_body
      |> SSEReader.parse_chunk()
      |> Enum.reduce({"", [], %{}, nil, nil}, &reduce_event/2)

    if text != "", do: send(stream_pid, StreamChunk.text(text))
    tc = if tool_calls != [], do: tool_calls, else: nil

    %Response{
      content: if(text == "", do: nil, else: text),
      tool_calls: tc,
      model: model,
      stop_reason: stop_reason,
      usage: usage
    }
  end

  defp stream_parse(raw_body, _stream_pid) when is_map(raw_body), do: parse_response(raw_body)

  defp reduce_event(%{"choices" => [%{"delta" => delta, "finish_reason" => fr} | _]} = event, {text, tc, _usage, _sr, _model}) do
    text = text <> (delta["content"] || "")
    model = event["model"]
    {text, tc, %{}, fr, model}
  end

  defp reduce_event(_, acc), do: acc
end
