defmodule ExClaw.Tool.Groups.FS do
  @moduledoc "Filesystem tool group — read, write, ls, grep, edit, move, delete."

  alias ExClaw.Tool.Metadata

  def tools do
    [
      {%Metadata{
         name: "read_file",
         group: :fs,
         description: "Read the contents of a file at the given path.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "path" => %{"type" => "string", "description" => "Absolute or relative file path"}
           },
           "required" => ["path"]
         }
       }, __MODULE__.ReadFile},

      {%Metadata{
         name: "write_file",
         group: :fs,
         description: "Write content to a file, creating it if it does not exist.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "path"    => %{"type" => "string"},
             "content" => %{"type" => "string"}
           },
           "required" => ["path", "content"]
         },
         dangerous: true
       }, __MODULE__.WriteFile},

      {%Metadata{
         name: "ls",
         group: :fs,
         description: "List files and directories in a path.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "path" => %{"type" => "string", "description" => "Directory path (default: .)"}
           },
           "required" => []
         }
       }, __MODULE__.Ls},

      {%Metadata{
         name: "grep",
         group: :fs,
         description: "Search for a pattern in files using grep.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "pattern" => %{"type" => "string"},
             "path"    => %{"type" => "string", "description" => "File or directory to search"},
             "flags"   => %{"type" => "string", "description" => "grep flags e.g. -r -n -i"}
           },
           "required" => ["pattern"]
         }
       }, __MODULE__.Grep},

      {%Metadata{
         name: "edit_file",
         group: :fs,
         description: "Replace a substring in a file with new content (first occurrence).",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "path"       => %{"type" => "string"},
             "old_string" => %{"type" => "string"},
             "new_string" => %{"type" => "string"}
           },
           "required" => ["path", "old_string", "new_string"]
         },
         dangerous: true
       }, __MODULE__.EditFile},

      {%Metadata{
         name: "move_file",
         group: :fs,
         description: "Move or rename a file.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "src"  => %{"type" => "string"},
             "dest" => %{"type" => "string"}
           },
           "required" => ["src", "dest"]
         },
         dangerous: true
       }, __MODULE__.MoveFile},

      {%Metadata{
         name: "delete_file",
         group: :fs,
         description: "Delete a file (non-recursive). Will not delete directories.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "path" => %{"type" => "string"}
           },
           "required" => ["path"]
         },
         dangerous: true
       }, __MODULE__.DeleteFile}
    ]
  end

  # -- Implementations --

  defmodule ReadFile do
    def execute(%{"path" => path}, _ctx) do
      case File.read(path) do
        {:ok, content} -> {:ok, content}
        {:error, reason} -> {:error, "read_file failed: #{reason}"}
      end
    end
  end

  defmodule WriteFile do
    def execute(%{"path" => path, "content" => content}, _ctx) do
      case File.write(path, content) do
        :ok -> {:ok, "Written #{byte_size(content)} bytes to #{path}"}
        {:error, reason} -> {:error, "write_file failed: #{reason}"}
      end
    end
  end

  defmodule Ls do
    def execute(input, _ctx) do
      path = Map.get(input, "path", ".")
      case File.ls(path) do
        {:ok, entries} -> {:ok, Enum.join(entries, "\n")}
        {:error, reason} -> {:error, "ls failed: #{reason}"}
      end
    end
  end

  defmodule Grep do
    def execute(%{"pattern" => pattern} = input, _ctx) do
      path = Map.get(input, "path", ".")
      flags = Map.get(input, "flags", "-r -n")
      cmd = "grep #{flags} #{shell_escape(pattern)} #{shell_escape(path)}"
      run_safe(cmd)
    end

    defp shell_escape(s), do: "'#{String.replace(s, "'", "'\\''")}'"

    defp run_safe(cmd) do
      case System.cmd("sh", ["-c", cmd], stderr_to_stdout: true) do
        {output, 0} -> {:ok, output}
        {output, 1} -> {:ok, output}   # grep returns 1 for no match
        {output, _} -> {:error, output}
      end
    end
  end

  defmodule EditFile do
    def execute(%{"path" => path, "old_string" => old, "new_string" => new}, _ctx) do
      with {:ok, content} <- File.read(path) do
        if String.contains?(content, old) do
          new_content = String.replace(content, old, new, global: false)
          case File.write(path, new_content) do
            :ok -> {:ok, "Replaced 1 occurrence in #{path}"}
            {:error, r} -> {:error, "edit_file write failed: #{r}"}
          end
        else
          {:error, "old_string not found in #{path}"}
        end
      else
        {:error, reason} -> {:error, "edit_file read failed: #{reason}"}
      end
    end
  end

  defmodule MoveFile do
    def execute(%{"src" => src, "dest" => dest}, _ctx) do
      case File.rename(src, dest) do
        :ok -> {:ok, "Moved #{src} → #{dest}"}
        {:error, reason} -> {:error, "move_file failed: #{reason}"}
      end
    end
  end

  defmodule DeleteFile do
    def execute(%{"path" => path}, _ctx) do
      case File.rm(path) do
        :ok -> {:ok, "Deleted #{path}"}
        {:error, reason} -> {:error, "delete_file failed: #{reason}"}
      end
    end
  end
end
