defmodule ExClaw.Auth.Context do
  @moduledoc """
  Authenticated request context resolved from Bearer token or device-pair auth.

  Carried through the request lifecycle and checked by RBAC before any
  privileged operation.
  """

  @enforce_keys [:user_id, :tenant_id, :role]
  defstruct [:user_id, :tenant_id, :role]

  @type role :: :admin | :operator | :viewer
  @type t :: %__MODULE__{
    user_id:   String.t(),
    tenant_id: String.t(),
    role:      role()
  }

  @doc "Returns true if the context carries the given role."
  def has_role?(%__MODULE__{role: role}, required), do: role == required

  @doc "Returns the role as a plain atom."
  def role(%__MODULE__{role: role}), do: role
end
