defmodule ExClaw.Store.Schema.Span do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "spans" do
    field :trace_id, :binary_id
    field :parent_span_id, :binary_id
    field :name, :string
    field :kind, :string, default: "internal"
    field :status, :string, default: "ok"
    field :attributes, :map, default: %{}
    field :started_at, :utc_datetime_usec
    field :ended_at, :utc_datetime_usec
    field :duration_ms, :integer
    timestamps(updated_at: false)
  end

  def changeset(span, attrs) do
    span
    |> cast(attrs, [:trace_id, :parent_span_id, :name, :kind, :status,
                    :attributes, :started_at, :ended_at, :duration_ms])
    |> validate_required([:trace_id, :name])
  end
end
