defmodule ExClaw do
  @moduledoc """
  ExClaw — Local-first, Actor-isolated, Durable Execution agent framework.

  ## Quick Start

      # Start a new session
      {:ok, session_id} = ExClaw.Repo.create_session("my-session")
      ExClaw.Session.Supervisor.start_session(session_id)

      # Send a message (synchronous, waits for full Thought-Act-Observe cycle)
      {:ok, reply} = ExClaw.Session.send_message(session_id, "List files in the current directory")

      # Approve dangerous tool if prompted
      ExClaw.Session.approve_tools(session_id, :granted)
  """
end
