defmodule ExClaw.Store.TeamStore do
  @moduledoc "Behaviour for agent team persistence."

  @type team_id :: String.t()
  @type task_id :: String.t()
  @type attrs :: map()

  @callback create_team(attrs()) :: {:ok, map()} | {:error, term()}
  @callback get_team(team_id()) :: {:ok, map()} | {:error, :not_found}
  @callback list_teams(opts :: map()) :: {:ok, [map()]}
  @callback delete_team(team_id()) :: :ok | {:error, term()}

  @callback create_task(attrs()) :: {:ok, map()} | {:error, term()}
  @callback get_task(task_id()) :: {:ok, map()} | {:error, :not_found}
  @callback list_tasks(team_id(), opts :: map()) :: {:ok, [map()]}
  @callback update_task(task_id(), attrs()) :: {:ok, map()} | {:error, term()}

  @doc "Atomic compare-and-swap: sets status=claimed only if status=pending."
  @callback claim_task(task_id(), worker_id :: String.t()) ::
              {:ok, map()} | {:error, :already_claimed | :not_found}

  @callback append_team_message(attrs()) :: {:ok, map()} | {:error, term()}
  @callback list_team_messages(team_id(), limit :: non_neg_integer()) :: {:ok, [map()]}
end
