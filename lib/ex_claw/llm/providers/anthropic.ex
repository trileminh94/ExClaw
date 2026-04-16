defmodule ExClaw.LLM.Providers.Anthropic do
  @moduledoc """
  Anthropic Claude provider.
  Implements ExClaw.LLM.Provider behaviour.

  Supports:
  - Blocking chat (messages API)
  - Streaming chat (SSE)
  - Extended thinking (budget_tokens)
  - Tool use
  """
  @behaviour ExClaw.LLM.Provider

  require Logger
  alias ExClaw.LLM.{Request, Response, StreamChunk, SSEReader}

  @api_base "https://api.anthropic.com"
  @anthropic_version "2023-06-01"
  @anthropic_beta "interleaved-thinking-2025-05-14"

  @impl true
  def name, do: "anthropic"

  @impl true
  def default_model, do: "claude-opus-4-6"

  @impl true
  def build_client(config) do
    api_key = Map.get(config, :api_key, "")

    Req.new(
      base_url: Map.get(config, :base_url, @api_base),
      headers: [
        {"x-api-key", api_key},
        {"anthropic-version", @anthropic_version},
        {"anthropic-beta", @anthropic_beta},
        {"content-type", "application/json"}
      ],
      receive_timeout: 120_000
    )
  end

  @impl true
  def chat(client, %Request{} = req) do
    body = build_body(req, false)

    case Req.post(client, url: "/v1/messages", json: body) do
      {:ok, %{status: 200, body: response}} ->
        {:ok, parse_response(response, req.model)}

      {:ok, %{status: 429, body: body}} ->
        {:error, {:api_error, 429, body}}

      {:ok, %{status: status, body: body}} ->
        Logger.error("[Anthropic] API error #{status}: #{inspect(body)}")
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error("[Anthropic] Request error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def chat_stream(client, %Request{} = req, stream_pid) do
    body = build_body(req, true)

    case Req.post(client, url: "/v1/messages", json: body) do
      {:ok, %{status: 200, body: raw_body}} ->
        response = stream_parse(raw_body, stream_pid, req.model)
        send(stream_pid, StreamChunk.done(response))
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        err = StreamChunk.error({:api_error, status, body})
        send(stream_pid, err)
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
      messages: format_messages(req.messages),
      stream: stream
    }

    body = if req.system, do: Map.put(body, :system, req.system), else: body
    body = if req.tools != [], do: Map.put(body, :tools, req.tools), else: body

    body =
      if req.thinking do
        Map.put(body, :thinking, %{
          type: "enabled",
          budget_tokens: req.thinking.budget_tokens
        })
      else
        body
      end

    body
  end

  defp parse_response(%{"content" => content_blocks} = raw, model) do
    thinking =
      content_blocks
      |> Enum.filter(&(&1["type"] == "thinking"))
      |> Enum.map(& &1["thinking"])
      |> Enum.join()
      |> then(fn t -> if t == "", do: nil, else: t end)

    text =
      content_blocks
      |> Enum.filter(&(&1["type"] == "text"))
      |> Enum.map(& &1["text"])
      |> Enum.join()
      |> then(fn t -> if t == "", do: nil, else: t end)

    tool_use = Enum.filter(content_blocks, &(&1["type"] == "tool_use"))

    tool_calls =
      if tool_use != [] do
        Enum.map(tool_use, fn block ->
          %{"name" => block["name"], "input" => block["input"], "id" => block["id"]}
        end)
      else
        nil
      end

    usage = raw["usage"] || %{}

    %Response{
      content: text,
      thinking: thinking,
      tool_calls: tool_calls,
      model: raw["model"] || model,
      stop_reason: raw["stop_reason"],
      usage: %{
        prompt_tokens: usage["input_tokens"] || 0,
        completion_tokens: usage["output_tokens"] || 0
      }
    }
  end

  defp parse_response(body, _model) do
    Logger.error("[Anthropic] Unexpected response shape: #{inspect(body)}")
    %Response{content: nil, tool_calls: nil}
  end

  # Parse a complete SSE response body (non-incremental, for simplicity in Phase 2).
  # Phase 3 will upgrade to true incremental streaming via Req async.
  defp stream_parse(raw_body, stream_pid, model) when is_binary(raw_body) do
    {text, thinking, tool_calls, usage, stop_reason, resp_model} =
      raw_body
      |> SSEReader.parse_chunk()
      |> Enum.reduce({"", "", [], %{}, nil, model}, &reduce_event/2)

    # Send text chunks
    if text != "" do
      send(stream_pid, StreamChunk.text(text))
    end

    if thinking != "" do
      send(stream_pid, StreamChunk.thinking(thinking))
    end

    tc = if tool_calls != [], do: tool_calls, else: nil

    %Response{
      content: if(text == "", do: nil, else: text),
      thinking: if(thinking == "", do: nil, else: thinking),
      tool_calls: tc,
      model: resp_model,
      stop_reason: stop_reason,
      usage: usage
    }
  end

  defp stream_parse(raw_body, stream_pid, model) when is_map(raw_body) do
    # Streaming was not actually used (synchronous response returned as map)
    response = parse_response(raw_body, model)
    send(stream_pid, StreamChunk.text(response.content || ""))
    response
  end

  defp reduce_event(%{"type" => "content_block_delta", "delta" => delta}, {text, thinking, tc, usage, sr, model}) do
    case delta do
      %{"type" => "text_delta", "text" => t} -> {text <> t, thinking, tc, usage, sr, model}
      %{"type" => "thinking_delta", "thinking" => t} -> {text, thinking <> t, tc, usage, sr, model}
      _ -> {text, thinking, tc, usage, sr, model}
    end
  end

  defp reduce_event(%{"type" => "message_delta", "delta" => delta, "usage" => u}, {text, thinking, tc, _usage, _sr, model}) do
    usage = %{
      prompt_tokens: get_in(u, ["input_tokens"]) || 0,
      completion_tokens: get_in(u, ["output_tokens"]) || 0
    }
    {text, thinking, tc, usage, delta["stop_reason"], model}
  end

  defp reduce_event(%{"type" => "message_start", "message" => msg}, {text, thinking, tc, _usage, sr, _model}) do
    usage_raw = msg["usage"] || %{}
    usage = %{
      prompt_tokens: usage_raw["input_tokens"] || 0,
      completion_tokens: usage_raw["output_tokens"] || 0
    }
    {text, thinking, tc, usage, sr, msg["model"]}
  end

  defp reduce_event(%{"type" => "content_block_start", "content_block" => %{"type" => "tool_use"} = block}, {text, thinking, tc, usage, sr, model}) do
    tool_call = %{"id" => block["id"], "name" => block["name"], "input" => %{}}
    {text, thinking, [tool_call | tc], usage, sr, model}
  end

  defp reduce_event(%{"type" => "content_block_delta", "delta" => %{"type" => "input_json_delta", "partial_json" => json}}, {text, thinking, [current | rest], usage, sr, model}) do
    # Accumulate partial JSON — merge into current tool call's input buffer
    # For simplicity, store raw partial JSON; final assembly in message_stop
    buffer = Map.get(current, "_input_buffer", "") <> json
    current = Map.put(current, "_input_buffer", buffer)
    {text, thinking, [current | rest], usage, sr, model}
  end

  defp reduce_event(%{"type" => "message_stop"}, {text, thinking, tc, usage, sr, model}) do
    # Finalize tool call inputs by parsing accumulated JSON buffers
    finalized_tc =
      Enum.map(tc, fn call ->
        case Map.get(call, "_input_buffer") do
          nil -> call
          buf ->
            input = case Jason.decode(buf) do
              {:ok, map} -> map
              _ -> %{}
            end
            call |> Map.put("input", input) |> Map.delete("_input_buffer")
        end
      end)

    {text, thinking, finalized_tc, usage, sr, model}
  end

  defp reduce_event(_, acc), do: acc

  defp format_messages(messages) do
    Enum.flat_map(messages, fn msg ->
      case msg do
        %{role: "tool", content: content, name: name} ->
          [%{role: "user", content: [%{type: "tool_result", content: content || "", tool_use_id: name}]}]

        %{tool_calls: tool_calls} when is_list(tool_calls) ->
          content =
            Enum.map(tool_calls, fn tc ->
              %{
                type: "tool_use",
                id: tc["id"] || tc[:id] || "call_#{:erlang.unique_integer([:positive])}",
                name: tc["name"],
                input: tc["input"] || %{}
              }
            end)

          [%{role: "assistant", content: content}]

        %{role: role, content: content} when not is_nil(content) ->
          [%{role: to_string(role), content: content}]

        _ ->
          []
      end
    end)
  end
end
