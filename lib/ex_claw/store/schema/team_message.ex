defmodule ExClaw.Store.Schema.TeamMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "team_messages" do
    field :team_id, :binary_id
    field :from_agent_id, :binary_id
    field :content, :string
    field :metadata, :map, default: %{}
    timestamps(updated_at: false)
  end

  def changeset(msg, attrs) do
    msg
    |> cast(attrs, [:team_id, :from_agent_id, :content, :metadata])
    |> validate_required([:team_id, :content])
  end
end
