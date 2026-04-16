defmodule ExClaw.Scheduler.SessionQueue do
  @moduledoc """
  Per-session FIFO run serializer.

  Ensures only one pipeline run executes at a time per session. Additional
  `enqueue` calls are buffered in a FIFO mailbox queue and dequeued
  automatically when the current run completes.

  Each SessionQueue GenServer is started on demand (keyed by session_id in
  the ExClaw.Registry) and terminates itself after draining the queue.

  Design mirrors GoClaw's channel-with-capacity-1 pattern:
  - While `running: true`, new tasks queue in the GenServer mailbox.
  - On task completion, the next queued task is kicked off immediately.
  - When the queue is empty and running=false, the GenServer shuts down.

  Usage:
      SessionQueue.enqueue(session_id, :main, fn -> Session.send_message(...) end)
  """
  use GenServer
  require Logger

  defstruct [:session_id, :lane, running: false, queue: :queue.new()]

  # -- Client API --

  @doc """
  Enqueue a task for a session. Starts the SessionQueue if not already running.

  `lane` is one of :main | :subagent | :team | :cron.
  `task_fn` is a zero-arity function executed by the Lane.
  """
  @spec enqueue(String.t(), atom(), (-> any())) :: :ok
  def enqueue(session_id, lane \\ :main, task_fn) do
    pid = ensure_started(session_id, lane)
    GenServer.cast(pid, {:enqueue, task_fn})
    :ok
  end

  # -- GenServer --

  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    lane = Keyword.get(opts, :lane, :main)
    GenServer.start_link(__MODULE__, [session_id: session_id, lane: lane],
      name: via(session_id))
  end

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    lane = Keyword.get(opts, :lane, :main)
    {:ok, %__MODULE__{session_id: session_id, lane: lane}}
  end

  @impl true
  def handle_cast({:enqueue, task_fn}, state) do
    if state.running do
      new_q = :queue.in(task_fn, state.queue)
      {:noreply, %{state | queue: new_q}}
    else
      {:noreply, dispatch(task_fn, state)}
    end
  end

  @impl true
  def handle_info(:task_done, state) do
    case :queue.out(state.queue) do
      {{:value, next_fn}, rest} ->
        {:noreply, dispatch(next_fn, %{state | queue: rest, running: false})}
      {:empty, _} ->
        # No more work — shut down
        {:stop, :normal, %{state | running: false}}
    end
  end

  # -- Private --

  defp dispatch(task_fn, state) do
    self_pid = self()
    wrapped_done = fn -> send(self_pid, :task_done) end
    ExClaw.Scheduler.Lane.submit(state.lane, task_fn, wrapped_done)
    %{state | running: true}
  end

  defp via(session_id), do: {:via, Registry, {ExClaw.Registry, {:session_queue, session_id}}}

  defp ensure_started(session_id, lane) do
    case Registry.lookup(ExClaw.Registry, {:session_queue, session_id}) do
      [{pid, _}] ->
        pid
      [] ->
        opts = [session_id: session_id, lane: lane]
        case DynamicSupervisor.start_child(ExClaw.Scheduler.QueueSupervisor,
               {__MODULE__, opts}) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end
    end
  end
end
