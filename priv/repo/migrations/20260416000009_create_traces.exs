defmodule ExClaw.Repo.Migrations.CreateTraces do
  use Ecto.Migration

  def change do
    create table(:traces, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, :binary_id, null: false
      add :agent_id, :binary_id
      add :user_id, :string
      add :tenant_id, :string
      add :model, :string
      add :provider, :string
      add :prompt_tokens, :integer, default: 0
      add :completion_tokens, :integer, default: 0
      add :cost_usd, :float, default: 0.0
      add :duration_ms, :integer
      add :metadata, :map, default: %{}
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create table(:spans, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :trace_id, references(:traces, type: :binary_id, on_delete: :delete_all), null: false
      add :parent_span_id, :binary_id
      add :name, :string, null: false
      add :kind, :string, default: "internal"
      add :status, :string, default: "ok"
      add :attributes, :map, default: %{}
      add :started_at, :utc_datetime_usec
      add :ended_at, :utc_datetime_usec
      add :duration_ms, :integer
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:traces, [:session_id])
    create index(:traces, [:agent_id, :user_id])
    create index(:spans, [:trace_id])
  end
end
