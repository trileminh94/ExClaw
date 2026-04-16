defmodule ExClaw.Store.TracingStore do
  @moduledoc "Behaviour for LLM call tracing persistence."

  @type trace_id :: String.t()
  @type attrs :: map()

  @callback create_trace(attrs()) :: {:ok, map()} | {:error, term()}
  @callback get_trace(trace_id()) :: {:ok, map()} | {:error, :not_found}
  @callback list_traces(session_id :: String.t(), opts :: map()) :: {:ok, [map()]}
  @callback append_span(attrs()) :: {:ok, map()} | {:error, term()}
  @callback list_spans(trace_id()) :: {:ok, [map()]}
end
