defmodule ExClaw.Store.SkillStore do
  @moduledoc "Behaviour for skills persistence (5-tier hierarchy)."

  @type skill_id :: String.t()
  @type attrs :: map()

  @callback create_skill(attrs()) :: {:ok, map()} | {:error, term()}
  @callback get_skill(skill_id()) :: {:ok, map()} | {:error, :not_found}
  @callback list_skills(opts :: map()) :: {:ok, [map()]}
  @callback update_skill(skill_id(), attrs()) :: {:ok, map()} | {:error, term()}
  @callback delete_skill(skill_id()) :: :ok | {:error, term()}
  @callback search_skills(query :: String.t(), opts :: map()) :: {:ok, [map()]}
end
