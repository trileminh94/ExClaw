defmodule ExClaw.Store.Schema.MemoryDocument do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "memory_documents" do
    field :agent_id, :binary_id
    field :user_id, :string
    field :tenant_id, :string
    # "episodic" | "semantic"
    field :type, :string, default: "episodic"
    field :content, :string
    field :summary, :string
    # JSON-encoded float array for vector similarity (small collections)
    field :embedding, :string
    field :metadata, :map, default: %{}
    field :session_id, :binary_id
    timestamps()
  end

  def changeset(doc, attrs) do
    doc
    |> cast(attrs, [:agent_id, :user_id, :tenant_id, :type, :content, :summary,
                    :embedding, :metadata, :session_id])
    |> validate_required([:content])
    |> validate_inclusion(:type, ["episodic", "semantic"])
  end
end
