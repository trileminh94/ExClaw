defmodule ExClaw.Store.SessionStore do
  @moduledoc "Behaviour for session persistence."

  @type session_id :: String.t()
  @type session :: map()
  @type attrs :: map()

  @callback create_session(attrs()) :: {:ok, session()} | {:error, term()}
  @callback get_session(session_id()) :: {:ok, session()} | {:error, :not_found}
  @callback list_sessions(user_id :: String.t()) :: {:ok, [session()]}
  @callback update_session(session_id(), attrs()) :: {:ok, session()} | {:error, term()}
  @callback delete_session(session_id()) :: :ok | {:error, term()}
  @callback hydrate_messages(session_id(), limit :: non_neg_integer()) :: {:ok, [map()]}
end
