defmodule ExClaw.Auth.RBAC do
  @moduledoc """
  Role-Based Access Control — compile-time permission matrix.

  Three roles:
  - :admin    — full control (all permissions)
  - :operator — run sessions, manage agents; cannot manage API keys or tenants
  - :viewer   — read-only access to sessions and agents

  Usage:
      RBAC.check_permission(auth_ctx, :agent_create)
      #=> :ok | {:error, :forbidden}
  """

  alias ExClaw.Auth.Context

  # Compile-time permission matrix.
  # Each permission is granted if the role is in the allow list.
  @permissions %{
    # Session permissions
    session_create:   [:admin, :operator],
    session_read:     [:admin, :operator, :viewer],
    session_list:     [:admin, :operator, :viewer],
    session_delete:   [:admin, :operator],

    # Agent permissions
    agent_create:     [:admin, :operator],
    agent_read:       [:admin, :operator, :viewer],
    agent_list:       [:admin, :operator, :viewer],
    agent_update:     [:admin, :operator],
    agent_delete:     [:admin],

    # Chat / message permissions
    chat_send:        [:admin, :operator],
    chat_approve:     [:admin, :operator],

    # Provider permissions
    provider_create:  [:admin],
    provider_read:    [:admin, :operator],
    provider_list:    [:admin, :operator],
    provider_update:  [:admin],
    provider_delete:  [:admin],

    # API key permissions
    api_key_create:   [:admin],
    api_key_read:     [:admin],
    api_key_list:     [:admin],
    api_key_revoke:   [:admin],

    # Skill permissions
    skill_create:     [:admin, :operator],
    skill_read:       [:admin, :operator, :viewer],
    skill_list:       [:admin, :operator, :viewer],
    skill_update:     [:admin, :operator],
    skill_delete:     [:admin],

    # Memory permissions
    memory_read:      [:admin, :operator, :viewer],
    memory_write:     [:admin, :operator],
    memory_delete:    [:admin],

    # Team permissions
    team_create:      [:admin, :operator],
    team_read:        [:admin, :operator, :viewer],
    team_list:        [:admin, :operator, :viewer],
    team_update:      [:admin, :operator],
    team_delete:      [:admin],

    # Cron permissions
    cron_create:      [:admin, :operator],
    cron_read:        [:admin, :operator, :viewer],
    cron_list:        [:admin, :operator, :viewer],
    cron_update:      [:admin, :operator],
    cron_delete:      [:admin],

    # Tracing / observability
    trace_read:       [:admin, :operator],
    trace_list:       [:admin, :operator],

    # System / config
    system_info:      [:admin, :operator, :viewer],
    config_read:      [:admin],
    config_update:    [:admin],

    # Tool management
    tool_list:        [:admin, :operator, :viewer],
    tool_execute:     [:admin, :operator]
  }

  @doc """
  Check if the given auth context has a specific permission.

  Returns `:ok` if allowed, `{:error, :forbidden}` otherwise.
  """
  @spec check_permission(Context.t(), atom()) :: :ok | {:error, :forbidden}
  def check_permission(%Context{role: role}, permission) do
    allowed_roles = Map.get(@permissions, permission, [])

    if role in allowed_roles do
      :ok
    else
      {:error, :forbidden}
    end
  end

  @doc """
  Returns all permissions granted to a role.
  """
  @spec permissions_for(Context.role()) :: [atom()]
  def permissions_for(role) do
    @permissions
    |> Enum.filter(fn {_perm, roles} -> role in roles end)
    |> Enum.map(fn {perm, _} -> perm end)
  end

  @doc """
  Returns the full permission matrix (for introspection / documentation).
  """
  @spec matrix() :: %{atom() => [Context.role()]}
  def matrix, do: @permissions
end
