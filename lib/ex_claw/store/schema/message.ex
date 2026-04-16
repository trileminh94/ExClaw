defmodule ExClaw.Store.Schema.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "messages" do
    field :session_id, :binary_id
    field :agent_id, :binary_id
    field :user_id, :string
    field :tenant_id, :string
    field :role, :string
    field :content, :string
    field :tool_calls, :map
    field :tool_results, :map
    field :thinking, :string
    timestamps(updated_at: false)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:session_id, :agent_id, :user_id, :tenant_id, :role, :content,
                    :tool_calls, :tool_results, :thinking])
    |> validate_required([:session_id, :role])
    |> validate_inclusion(:role, ["user", "assistant", "tool", "system"])
  end
end
