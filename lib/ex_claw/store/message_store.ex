defmodule ExClaw.Store.MessageStore do
  @moduledoc "Behaviour for chat message persistence."

  @type session_id :: String.t()
  @type message :: map()
  @type attrs :: map()

  @callback append_message(attrs()) :: {:ok, message()} | {:error, term()}
  @callback list_messages(session_id(), opts :: map()) :: {:ok, [message()]}
  @callback delete_messages(session_id()) :: :ok | {:error, term()}
end
