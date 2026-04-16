defmodule ExClaw.Tool.Runner do
  @moduledoc """
  Tool execution layer.

  Uses MuonTrap for OS-level process reaping to prevent zombies
  and limit resource usage for shell-based tools.
  """

  @doc "Return Anthropic-format tool definitions for all built-in tools."
  def tool_definitions do
    [
      %{name: "bash", description: "Execute a bash command on the local machine.",
        input_schema: %{type: "object", properties: %{command: %{type: "string", description: "The bash command to run"}}, required: ["command"]}},
      %{name: "read_file", description: "Read the contents of a local file.",
        input_schema: %{type: "object", properties: %{path: %{type: "string", description: "Absolute or relative file path"}}, required: ["path"]}},
      %{name: "ls", description: "List directory contents.",
        input_schema: %{type: "object", properties: %{path: %{type: "string", description: "Directory path"}}, required: ["path"]}},
      %{name: "grep", description: "Search for a pattern in files.",
        input_schema: %{type: "object", properties: %{pattern: %{type: "string"}, path: %{type: "string"}}, required: ["pattern", "path"]}},
      %{name: "curl", description: "Fetch a URL.",
        input_schema: %{type: "object", properties: %{url: %{type: "string"}}, required: ["url"]}},
      %{name: "search_local_docs", description: "Search indexed local Markdown knowledge base via FTS5.",
        input_schema: %{type: "object", properties: %{query: %{type: "string", description: "Full-text search query"}}, required: ["query"]}}
    ]
  end

  @doc "Execute a named tool with the given arguments map."
  def execute("bash", %{"command" => cmd}) do
    case MuonTrap.cmd("bash", ["-c", cmd],
      timeout: 30_000,
      into: "",
      stderr_to_stdout: true
    ) do
      {output, 0} -> {:ok, output}
      {output, exit_code} -> {:error, "Exit #{exit_code}: #{output}"}
    end
  end

  def execute("read_file", %{"path" => path}) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, "Cannot read #{path}: #{:file.format_error(reason)}"}
    end
  end

  def execute("ls", %{"path" => path}) do
    case MuonTrap.cmd("ls", ["-la", path], timeout: 5_000, into: "", stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, output}
    end
  end

  def execute("grep", %{"pattern" => pattern, "path" => path}) do
    case MuonTrap.cmd("grep", ["-r", "-n", pattern, path], timeout: 10_000, into: "", stderr_to_stdout: true) do
      {output, _} -> {:ok, output}
    end
  end

  def execute("curl", %{"url" => url}) do
    case MuonTrap.cmd("curl", ["-sL", "--max-time", "15", url], timeout: 20_000, into: "", stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, exit_code} -> {:error, "curl exit #{exit_code}: #{output}"}
    end
  end

  def execute("search_local_docs", %{"query" => query}) do
    case ExClaw.Repo.search_knowledge(query) do
      {:ok, results} ->
        formatted =
          results
          |> Enum.map(fn %{path: p, snippet: s} -> "## #{p}\n#{s}" end)
          |> Enum.join("\n\n")
        {:ok, if(formatted == "", do: "No results found.", else: formatted)}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  def execute(tool_name, _args) do
    {:error, "Unknown tool: #{tool_name}"}
  end
end
