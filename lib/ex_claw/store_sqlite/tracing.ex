defmodule ExClaw.StoreSQLite.Tracing do
  @moduledoc "SQLite implementation of ExClaw.Store.TracingStore."
  @behaviour ExClaw.Store.TracingStore

  import Ecto.Query
  alias ExClaw.Repo
  alias ExClaw.Store.Schema.{Trace, Span}

  @impl true
  def create_trace(attrs) do
    %Trace{} |> Trace.changeset(attrs) |> Repo.insert() |> result()
  end

  @impl true
  def get_trace(id) do
    case Repo.get(Trace, id) do
      nil -> {:error, :not_found}
      t -> {:ok, t}
    end
  end

  @impl true
  def list_traces(session_id, opts) do
    limit = Map.get(opts, :limit, 50)

    traces =
      from(t in Trace,
        where: t.session_id == ^session_id,
        order_by: [desc: t.inserted_at],
        limit: ^limit
      )
      |> Repo.all()

    {:ok, traces}
  end

  @impl true
  def append_span(attrs) do
    %Span{} |> Span.changeset(attrs) |> Repo.insert() |> result()
  end

  @impl true
  def list_spans(trace_id) do
    spans =
      from(s in Span,
        where: s.trace_id == ^trace_id,
        order_by: [asc: s.started_at]
      )
      |> Repo.all()

    {:ok, spans}
  end

  defp result({:ok, struct}), do: {:ok, struct}
  defp result({:error, changeset}), do: {:error, changeset}
end
