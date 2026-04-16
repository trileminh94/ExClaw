defmodule ExClaw.Tool.Supervisor do
  @moduledoc "DynamicSupervisor for isolated tool execution Tasks."
  use DynamicSupervisor

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
