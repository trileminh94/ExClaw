defmodule ExClaw.Session.Supervisor do
  @moduledoc "DynamicSupervisor that manages Agent Actor GenServers."
  use DynamicSupervisor

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_session(session_id) do
    spec = {ExClaw.Session, session_id: session_id}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_session(session_id) do
    case Registry.lookup(ExClaw.Registry, {:session, session_id}) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end
end
