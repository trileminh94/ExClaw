defmodule ExClaw.Store.AgentStore do
  @moduledoc "Behaviour for agent definition persistence."

  @type agent_id :: String.t()
  @type agent :: map()
  @type attrs :: map()

  @callback create_agent(attrs()) :: {:ok, agent()} | {:error, term()}
  @callback get_agent(agent_id()) :: {:ok, agent()} | {:error, :not_found}
  @callback get_agent_by_key(key :: String.t()) :: {:ok, agent()} | {:error, :not_found}
  @callback list_agents(opts :: map()) :: {:ok, [agent()]}
  @callback update_agent(agent_id(), attrs()) :: {:ok, agent()} | {:error, term()}
  @callback delete_agent(agent_id()) :: :ok | {:error, term()}
end
