defmodule ExClaw.Watcher do
  @moduledoc """
  FileSystem watcher for the knowledge directory.

  When a .md file changes, reads it and upserts into the
  knowledge_fts FTS5 table for local-first RAG search.
  """
  use GenServer
  require Logger

  def start_link(opts) do
    path = Keyword.get(opts, :path, "./knowledge")
    GenServer.start_link(__MODULE__, path, name: __MODULE__)
  end

  @impl true
  def init(path) do
    File.mkdir_p!(path)
    {:ok, watcher_pid} = FileSystem.start_link(dirs: [path])
    FileSystem.subscribe(watcher_pid)
    Logger.info("[Watcher] Watching #{path} for Markdown changes")
    # Index existing files on startup
    index_directory(path)
    {:ok, %{watcher_pid: watcher_pid, path: path}}
  end

  @impl true
  def handle_info({:file_event, _watcher_pid, {file_path, events}}, state) do
    if String.ends_with?(file_path, ".md") and not Enum.member?(events, :removed) do
      index_file(file_path)
    end

    if String.ends_with?(file_path, ".md") and Enum.member?(events, :removed) do
      Logger.info("[Watcher] File removed: #{file_path} (not removing from index)")
    end

    {:noreply, state}
  end

  def handle_info({:file_event, _watcher_pid, :stop}, state) do
    Logger.warning("[Watcher] FileSystem watcher stopped")
    {:noreply, state}
  end

  # -- Private --

  defp index_directory(path) do
    path
    |> Path.join("**/*.md")
    |> Path.wildcard()
    |> Enum.each(&index_file/1)
  end

  defp index_file(path) do
    case File.read(path) do
      {:ok, content} ->
        last_modified = path |> File.stat!() |> Map.get(:mtime) |> inspect()
        :ok = ExClaw.Repo.upsert_knowledge(path, content, last_modified)
        Logger.debug("[Watcher] Indexed #{path}")

      {:error, reason} ->
        Logger.error("[Watcher] Failed to read #{path}: #{inspect(reason)}")
    end
  end
end
