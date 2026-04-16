defmodule ExClaw.Store.ContextFileStore do
  @moduledoc "Behaviour for agent/user context file persistence (SOUL.md, USER.md, etc.)."

  @type attrs :: map()

  @callback get_agent_file(agent_id :: String.t(), filename :: String.t()) ::
              {:ok, String.t()} | {:error, :not_found}
  @callback get_user_file(agent_id :: String.t(), user_id :: String.t(), filename :: String.t()) ::
              {:ok, String.t()} | {:error, :not_found}
  @callback upsert_agent_file(attrs()) :: :ok | {:error, term()}
  @callback upsert_user_file(attrs()) :: :ok | {:error, term()}
  @callback list_agent_files(agent_id :: String.t()) :: {:ok, [map()]}
  @callback list_user_files(agent_id :: String.t(), user_id :: String.t()) :: {:ok, [map()]}
  @callback delete_agent_file(agent_id :: String.t(), filename :: String.t()) ::
              :ok | {:error, term()}
end
