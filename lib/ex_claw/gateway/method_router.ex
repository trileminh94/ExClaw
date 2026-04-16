defmodule ExClaw.Gateway.MethodRouter do
  @moduledoc """
  Routes incoming WebSocket method strings to the appropriate handler module.

  Method namespacing:
  - `chat.*`    → Methods.Chat
  - `session.*` → Methods.Sessions
  - `agent.*`   → Methods.Agents
  - `system.*`  → Methods.System
  """

  alias ExClaw.Auth.Context
  alias ExClaw.Gateway.Methods

  @doc """
  Dispatch a decoded request to the correct handler.

  `ws_pid` is the WebSocket handler process — passed to handlers that
  support streaming (chat.send with stream: true).

  Returns:
  - `{:ok, result_map}` — success; caller wraps in encode_result
  - `{:async, session_id}` — streaming started; no immediate result to send
  - `{:error, code, message}` — failure; caller wraps in encode_error
  """
  @spec dispatch(String.t(), map(), Context.t(), pid()) ::
    {:ok, map()} | {:async, String.t()} | {:error, non_neg_integer(), String.t()}
  def dispatch(method, params, %Context{} = auth, ws_pid \\ nil) do
    namespace = method_namespace(method)

    case namespace do
      "chat"    -> Methods.Chat.handle(method, params, auth, ws_pid)
      "session" -> Methods.Sessions.handle(method, params, auth)
      "agent"   -> Methods.Agents.handle(method, params, auth)
      "system"  -> Methods.System.handle(method, params, auth)
      _         -> {:error, 404, "unknown method namespace: #{namespace}"}
    end
  end

  defp method_namespace(method) do
    case String.split(method, ".", parts: 2) do
      [ns, _] -> ns
      [ns]    -> ns
    end
  end
end
