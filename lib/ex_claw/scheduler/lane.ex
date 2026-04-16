defmodule ExClaw.Scheduler.Lane do
  @moduledoc """
  Concurrency-capped lane for task execution.

  Holds an ETS atomic counter as a semaphore. When the running count is below
  the cap, tasks are spawned immediately under Tool.Supervisor. When at cap,
  requests queue in the GenServer mailbox (Erlang's built-in FIFO).

  On each task completion (monitored via Process.monitor), the semaphore is
  decremented and the next queued request (if any) is dispatched.

  Lane names: :main | :subagent | :team | :cron
  Caps (configurable via :ex_claw, :lane_caps):
    main=30, subagent=50, team=100, cron=30
  """
  use GenServer
  require Logger

  defstruct [:name, :cap, :running, :queue]

  @default_caps %{main: 30, subagent: 50, team: 100, cron: 30}

  # -- Client API --

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via(name))
  end

  @doc """
  Submit a task function to run in this lane.

  Returns `:queued` immediately — the caller should not block waiting for the
  task result (use the session queue pattern for that).

  `task_fn` is a zero-arity function. It runs inside a Task under Tool.Supervisor.
  `on_done` is a zero-arity callback invoked after the task completes (or crashes).
  """
  @spec submit(atom(), (-> any()), (-> any())) :: :queued
  def submit(lane_name, task_fn, on_done \\ fn -> :ok end) do
    GenServer.cast(via(lane_name), {:submit, task_fn, on_done})
    :queued
  end

  @doc "Current running count for this lane."
  @spec running(atom()) :: non_neg_integer()
  def running(lane_name), do: GenServer.call(via(lane_name), :running)

  @doc "Current queue depth for this lane."
  @spec queued(atom()) :: non_neg_integer()
  def queued(lane_name), do: GenServer.call(via(lane_name), :queued)

  # -- GenServer --

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    caps = Application.get_env(:ex_claw, :lane_caps, @default_caps)
    cap = Map.get(caps, name, 30)

    {:ok, %__MODULE__{name: name, cap: cap, running: 0, queue: :queue.new()}}
  end

  @impl true
  def handle_cast({:submit, task_fn, on_done}, state) do
    if state.running < state.cap do
      {:noreply, spawn_task(task_fn, on_done, state)}
    else
      Logger.debug("[Lane #{state.name}] at cap #{state.cap}, queuing task")
      new_q = :queue.in({task_fn, on_done}, state.queue)
      {:noreply, %{state | queue: new_q}}
    end
  end

  @impl true
  def handle_call(:running, _from, state), do: {:reply, state.running, state}
  def handle_call(:queued, _from, state),  do: {:reply, :queue.len(state.queue), state}

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    if reason not in [:normal, :shutdown] do
      Logger.warning("[Lane #{state.name}] task exited: #{inspect(reason)}")
    end

    new_running = max(0, state.running - 1)
    state = %{state | running: new_running}

    # Dequeue next task if any
    case :queue.out(state.queue) do
      {{:value, {task_fn, on_done}}, rest} ->
        {:noreply, spawn_task(task_fn, on_done, %{state | queue: rest})}
      {:empty, _} ->
        {:noreply, state}
    end
  end

  # -- Private --

  defp spawn_task(task_fn, on_done, state) do
    # Wrap so on_done fires regardless of success/crash
    wrapped = fn ->
      try do
        task_fn.()
      after
        on_done.()
      end
    end

    {:ok, pid} = Task.Supervisor.start_child(ExClaw.Tool.Supervisor, wrapped)
    Process.monitor(pid)
    %{state | running: state.running + 1}
  end

  defp via(name), do: {:via, Registry, {ExClaw.Registry, {:lane, name}}}
end
