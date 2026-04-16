defmodule ExClaw.Context do
  @moduledoc """
  Process-dictionary helpers for threading (user_id, agent_id, tenant_id, role)
  through a single GenServer call without passing them as explicit params at
  every function boundary.

  Use explicit function parameters for cross-process calls.
  Only use this module for deep in-process propagation within one GenServer call.
  """

  @keys [:user_id, :agent_id, :tenant_id, :role]

  @doc "Put all context keys at once from a map/keyword list."
  def put(attrs) when is_map(attrs) or is_list(attrs) do
    Enum.each(@keys, fn key ->
      case attrs[key] do
        nil -> :ok
        val -> put_key(key, val)
      end
    end)
  end

  def put_user_id(id), do: put_key(:user_id, id)
  def put_agent_id(id), do: put_key(:agent_id, id)
  def put_tenant_id(id), do: put_key(:tenant_id, id)
  def put_role(role), do: put_key(:role, role)

  def get_user_id, do: Process.get({__MODULE__, :user_id})
  def get_agent_id, do: Process.get({__MODULE__, :agent_id})
  def get_tenant_id, do: Process.get({__MODULE__, :tenant_id})
  def get_role, do: Process.get({__MODULE__, :role}, :viewer)

  @doc "Returns a map of all set context keys (omits nil values)."
  def to_map do
    @keys
    |> Enum.flat_map(fn key ->
      case Process.get({__MODULE__, key}) do
        nil -> []
        val -> [{key, val}]
      end
    end)
    |> Map.new()
  end

  @doc "Clear all context keys from the process dictionary."
  def clear do
    Enum.each(@keys, fn key -> Process.delete({__MODULE__, key}) end)
  end

  defp put_key(key, value), do: Process.put({__MODULE__, key}, value)
end
