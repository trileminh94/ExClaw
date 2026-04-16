defmodule ExClaw.Store.Schema.Trace do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "traces" do
    field :session_id, :binary_id
    field :agent_id, :binary_id
    field :user_id, :string
    field :tenant_id, :string
    field :model, :string
    field :provider, :string
    field :prompt_tokens, :integer, default: 0
    field :completion_tokens, :integer, default: 0
    field :cost_usd, :float, default: 0.0
    field :duration_ms, :integer
    field :metadata, :map, default: %{}
    timestamps(updated_at: false)
  end

  def changeset(trace, attrs) do
    trace
    |> cast(attrs, [:session_id, :agent_id, :user_id, :tenant_id, :model, :provider,
                    :prompt_tokens, :completion_tokens, :cost_usd, :duration_ms, :metadata])
    |> validate_required([:session_id])
  end
end
