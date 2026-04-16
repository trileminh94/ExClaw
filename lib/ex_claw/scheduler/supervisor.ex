defmodule ExClaw.Scheduler.Supervisor do
  @moduledoc """
  Top-level supervisor for the scheduling subsystem.

  Children (start order matters):
  1. AdaptiveThrottle  — ETS table for context throttling
  2. QueueSupervisor   — DynamicSupervisor for per-session queues
  3. LaneManager       — Supervisor owning the four Lane GenServers
  """
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      ExClaw.Scheduler.AdaptiveThrottle,
      {DynamicSupervisor, name: ExClaw.Scheduler.QueueSupervisor, strategy: :one_for_one},
      ExClaw.Scheduler.LaneManager
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
