defmodule ExClaw.Scheduler.LaneManager do
  @moduledoc """
  Owns and starts the four concurrency lanes under a DynamicSupervisor.

  Lanes: :main, :subagent, :team, :cron

  This is a plain GenServer that starts the four Lane children at init time
  so they are properly supervised under Scheduler.Supervisor.
  """
  use Supervisor

  @lanes [:main, :subagent, :team, :cron]

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = Enum.map(@lanes, fn name ->
      Supervisor.child_spec({ExClaw.Scheduler.Lane, [name: name]}, id: name)
    end)

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc "Returns the list of lane names."
  def lanes, do: @lanes
end
