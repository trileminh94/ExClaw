defmodule ExClaw.Tool.Groups.Delegation do
  @moduledoc "Delegation tool group — spawn a subagent session to handle a subtask."

  alias ExClaw.Tool.Metadata

  def tools do
    [
      {%Metadata{
         name: "delegate",
         group: :delegation,
         description: "Spawn a subagent to handle a subtask and return its response. " <>
                      "Use for parallelizable subtasks or tasks requiring different expertise.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "task"     => %{"type" => "string", "description" => "Task description for the subagent"},
             "agent_id" => %{"type" => "string", "description" => "Optional specific agent to use"}
           },
           "required" => ["task"]
         },
         rate_limit: 5
       }, __MODULE__.Delegate}
    ]
  end

  defmodule Delegate do
    def execute(%{"task" => task} = input, ctx) do
      agent_id   = Map.get(input, "agent_id")
      user_id    = Map.get(ctx, :user_id)
      tenant_id  = Map.get(ctx, :tenant_id)
      session_id = Ecto.UUID.generate()

      opts = [
        session_id: session_id,
        agent_id:   agent_id,
        user_id:    user_id,
        tenant_id:  tenant_id
      ]

      case DynamicSupervisor.start_child(ExClaw.Session.Supervisor, {ExClaw.Session, opts}) do
        {:ok, _pid} ->
          case ExClaw.Session.send_message(session_id, task) do
            {:ok, content} -> {:ok, content}
            {:error, reason} -> {:error, "delegate failed: #{inspect(reason)}"}
          end

        {:error, reason} ->
          {:error, "delegate: failed to start subagent: #{inspect(reason)}"}
      end
    end
  end
end
