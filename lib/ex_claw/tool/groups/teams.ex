defmodule ExClaw.Tool.Groups.Teams do
  @moduledoc "Team tool group — task board and team messaging operations."

  alias ExClaw.Tool.Metadata
  alias ExClaw.StoreSQLite.Team, as: TeamStore

  def tools do
    [
      {%Metadata{
         name: "task_create",
         group: :teams,
         description: "Create a new task on the team task board.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "team_id"     => %{"type" => "string"},
             "title"       => %{"type" => "string"},
             "description" => %{"type" => "string"},
             "priority"    => %{"type" => "string", "enum" => ["low", "medium", "high"]}
           },
           "required" => ["team_id", "title"]
         }
       }, __MODULE__.TaskCreate},

      {%Metadata{
         name: "task_claim",
         group: :teams,
         description: "Atomically claim a pending task for this agent.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "task_id" => %{"type" => "string"}
           },
           "required" => ["task_id"]
         }
       }, __MODULE__.TaskClaim},

      {%Metadata{
         name: "task_update",
         group: :teams,
         description: "Update the status or metadata of a task.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "task_id" => %{"type" => "string"},
             "status"  => %{"type" => "string",
                            "enum" => ["pending", "claimed", "in_progress", "done", "blocked", "failed"]},
             "output"  => %{"type" => "string", "description" => "Task output / result"}
           },
           "required" => ["task_id"]
         }
       }, __MODULE__.TaskUpdate},

      {%Metadata{
         name: "task_complete",
         group: :teams,
         description: "Mark a task as done with optional output.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "task_id" => %{"type" => "string"},
             "output"  => %{"type" => "string"}
           },
           "required" => ["task_id"]
         }
       }, __MODULE__.TaskComplete},

      {%Metadata{
         name: "task_block",
         group: :teams,
         description: "Mark a task as blocked and escalate to team lead.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "task_id" => %{"type" => "string"},
             "reason"  => %{"type" => "string"}
           },
           "required" => ["task_id", "reason"]
         }
       }, __MODULE__.TaskBlock},

      {%Metadata{
         name: "message_team",
         group: :teams,
         description: "Send a message to the team mailbox.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "team_id" => %{"type" => "string"},
             "content" => %{"type" => "string"}
           },
           "required" => ["team_id", "content"]
         }
       }, __MODULE__.MessageTeam}
    ]
  end

  defmodule TaskCreate do
    def execute(%{"team_id" => team_id, "title" => title} = input, ctx) do
      attrs = %{
        team_id:     team_id,
        title:       title,
        description: Map.get(input, "description"),
        priority:    Map.get(input, "priority", "medium"),
        created_by:  Map.get(ctx, :agent_id),
        tenant_id:   Map.get(ctx, :tenant_id),
        status:      "pending"
      }
      case TeamStore.create_task(attrs) do
        {:ok, task} -> {:ok, "Task created: #{task.id}"}
        {:error, r} -> {:error, "task_create failed: #{inspect(r)}"}
      end
    end
  end

  defmodule TaskClaim do
    def execute(%{"task_id" => task_id}, ctx) do
      worker_id = Map.get(ctx, :agent_id)
      case TeamStore.claim_task(task_id, worker_id) do
        {:ok, task} -> {:ok, "Claimed task #{task.id}: #{task.title}"}
        {:error, :already_claimed} -> {:error, "Task #{task_id} already claimed"}
        {:error, r} -> {:error, "task_claim failed: #{inspect(r)}"}
      end
    end
  end

  defmodule TaskUpdate do
    def execute(%{"task_id" => task_id} = input, _ctx) do
      attrs = Map.take(input, ["status", "output"]) |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
      case TeamStore.update_task(task_id, attrs) do
        {:ok, _} -> {:ok, "Task #{task_id} updated"}
        {:error, r} -> {:error, "task_update failed: #{inspect(r)}"}
      end
    end
  end

  defmodule TaskComplete do
    def execute(%{"task_id" => task_id} = input, _ctx) do
      attrs = %{status: "done", output: Map.get(input, "output")}
      case TeamStore.update_task(task_id, attrs) do
        {:ok, _} -> {:ok, "Task #{task_id} marked done"}
        {:error, r} -> {:error, "task_complete failed: #{inspect(r)}"}
      end
    end
  end

  defmodule TaskBlock do
    def execute(%{"task_id" => task_id, "reason" => reason}, _ctx) do
      attrs = %{status: "blocked", output: "BLOCKED: #{reason}"}
      case TeamStore.update_task(task_id, attrs) do
        {:ok, _} ->
          ExClaw.EventBus.publish({:team, :blocker}, %{task_id: task_id, reason: reason})
          {:ok, "Task #{task_id} marked blocked — lead notified"}
        {:error, r} ->
          {:error, "task_block failed: #{inspect(r)}"}
      end
    end
  end

  defmodule MessageTeam do
    def execute(%{"team_id" => team_id, "content" => content}, ctx) do
      attrs = %{
        team_id:   team_id,
        sender_id: Map.get(ctx, :agent_id),
        content:   content
      }
      case TeamStore.append_team_message(attrs) do
        {:ok, _} -> {:ok, "Message sent to team #{team_id}"}
        {:error, r} -> {:error, "message_team failed: #{inspect(r)}"}
      end
    end
  end
end
