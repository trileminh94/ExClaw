defmodule ExClaw.Tool.Groups.Runtime do
  @moduledoc "Runtime tool group — bash execution via MuonTrap with deny-pattern guard."

  alias ExClaw.Tool.{Metadata, DenyPatterns}

  def tools do
    [
      {%Metadata{
         name: "bash",
         group: :runtime,
         description: "Execute a bash command. Restricted: no rm -rf, no piped curl|sh, no privilege escalation.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "command" => %{"type" => "string", "description" => "Shell command to execute"},
             "timeout" => %{"type" => "integer", "description" => "Timeout in seconds (default 30)"}
           },
           "required" => ["command"]
         },
         dangerous: true,
         rate_limit: 30
       }, __MODULE__.Bash},

      {%Metadata{
         name: "search_local_docs",
         group: :runtime,
         description: "Full-text search through the local knowledge base.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "query" => %{"type" => "string", "description" => "Search query"}
           },
           "required" => ["query"]
         }
       }, __MODULE__.SearchLocalDocs}
    ]
  end

  defmodule Bash do
    def execute(%{"command" => command} = input, _ctx) do
      case DenyPatterns.check(command) do
        {:denied, group, reason} ->
          {:error, "Command denied — matches #{group} deny pattern: #{reason}"}

        :ok ->
          timeout_ms = Map.get(input, "timeout", 30) * 1000

          try do
            case MuonTrap.cmd("bash", ["-c", command],
                   timeout: timeout_ms,
                   stderr_to_stdout: true) do
              {output, 0} -> {:ok, output}
              {output, code} -> {:error, "exit #{code}:\n#{output}"}
            end
          catch
            :exit, {:timeout, _} -> {:error, "bash: command timed out"}
          end
      end
    end
  end

  defmodule SearchLocalDocs do
    def execute(%{"query" => query}, _ctx) do
      case ExClaw.Repo.search_knowledge(query) do
        {:ok, results} when results == [] ->
          {:ok, "No results found for: #{query}"}

        {:ok, results} ->
          formatted =
            results
            |> Enum.map(fn r -> "### #{r.path}\n#{String.slice(r.content, 0, 500)}" end)
            |> Enum.join("\n\n---\n\n")

          {:ok, formatted}

        {:error, reason} ->
          {:error, "search_local_docs failed: #{inspect(reason)}"}
      end
    end
  end
end
