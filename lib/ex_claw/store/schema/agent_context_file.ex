defmodule ExClaw.Store.Schema.AgentContextFile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "agent_context_files" do
    field :agent_id, :binary_id
    field :filename, :string
    field :content, :string
    timestamps()
  end

  def changeset(file, attrs) do
    file
    |> cast(attrs, [:agent_id, :filename, :content])
    |> validate_required([:agent_id, :filename, :content])
    |> unique_constraint([:agent_id, :filename])
  end
end
