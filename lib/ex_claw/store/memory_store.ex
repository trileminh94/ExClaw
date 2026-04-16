defmodule ExClaw.Store.MemoryStore do
  @moduledoc "Behaviour for episodic/semantic memory document persistence."

  @type doc_id :: String.t()
  @type attrs :: map()

  @callback create_document(attrs()) :: {:ok, map()} | {:error, term()}
  @callback get_document(doc_id()) :: {:ok, map()} | {:error, :not_found}
  @callback list_documents(agent_id :: String.t(), user_id :: String.t()) :: {:ok, [map()]}
  @callback update_document(doc_id(), attrs()) :: {:ok, map()} | {:error, term()}
  @callback delete_document(doc_id()) :: :ok | {:error, term()}
  @callback search_documents(query :: String.t(), opts :: map()) :: {:ok, [map()]}
end
