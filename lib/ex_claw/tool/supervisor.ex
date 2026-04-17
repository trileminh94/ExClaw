defmodule ExClaw.Tool.Supervisor do
  @moduledoc """
  Task.Supervisor for isolated tool execution.

  Lane.ex spawns tasks here via Task.Supervisor.start_child/2.
  The supervisor monitors each task and restarts crashed ones only if
  they are permanent (tools use :temporary restart by default — crash = done).
  """

  def start_link(opts \\ []) do
    Task.Supervisor.start_link([name: __MODULE__] ++ opts)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 5_000
    }
  end
end
