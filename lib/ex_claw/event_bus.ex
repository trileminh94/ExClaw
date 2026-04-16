defmodule ExClaw.EventBus do
  @moduledoc """
  Lightweight Registry-based pub/sub for session-scoped events.

  Subscribers register with a topic key. Publishers dispatch events to all
  registered subscribers for that topic.

  Topics used in Phase 3:
  - `{:session, session_id}` — streaming chunks + done events for a session

  Phase 6 will add:
  - `{:team, team_id}` — team task and message events
  """

  @registry ExClaw.EventBus.Registry

  def child_spec(_opts) do
    Registry.child_spec(keys: :duplicate, name: @registry)
  end

  @doc "Subscribe the current process to a topic."
  def subscribe(topic) do
    {:ok, _} = Registry.register(@registry, topic, nil)
    :ok
  end

  @doc "Unsubscribe the current process from a topic."
  def unsubscribe(topic) do
    Registry.unregister(@registry, topic)
    :ok
  end

  @doc "Publish an event to all subscribers of a topic."
  def publish(topic, event) do
    Registry.dispatch(@registry, topic, fn entries ->
      Enum.each(entries, fn {pid, _} -> send(pid, event) end)
    end)
  end
end
