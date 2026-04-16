defmodule ExClaw.Bootstrap.FileRouter do
  @moduledoc """
  ETS-backed cache of agent/user context file content (SOUL.md, USER.md, etc.).

  Phase 2: files are loaded from priv/bootstrap/ seed templates and the DB
  (agent_context_files, user_context_files tables). Serves content to ContextStage.

  Phase 5 will add live reload and per-user override resolution.
  """
  use GenServer
  require Logger

  @table :exclaw_context_files

  # -- Client API --

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get content of an agent-level context file."
  @spec get_file(agent_id :: String.t() | nil, filename :: String.t()) ::
          {:ok, String.t()} | {:error, :not_found}
  def get_file(nil, _filename), do: {:error, :not_found}

  def get_file(agent_id, filename) do
    case :ets.lookup(@table, {:agent, agent_id, filename}) do
      [{_, content}] -> {:ok, content}
      [] ->
        # Try loading from DB on miss
        GenServer.call(__MODULE__, {:load_agent_file, agent_id, filename})
    end
  end

  @doc "Get content of a user-specific context file."
  @spec get_user_file(agent_id :: String.t() | nil, user_id :: String.t() | nil, filename :: String.t()) ::
          {:ok, String.t()} | {:error, :not_found}
  def get_user_file(nil, _uid, _filename), do: {:error, :not_found}
  def get_user_file(_aid, nil, _filename), do: {:error, :not_found}

  def get_user_file(agent_id, user_id, filename) do
    case :ets.lookup(@table, {:user, agent_id, user_id, filename}) do
      [{_, content}] -> {:ok, content}
      [] ->
        GenServer.call(__MODULE__, {:load_user_file, agent_id, user_id, filename})
    end
  end

  @doc "Invalidate cached files for an agent (e.g. after update)."
  def invalidate(agent_id) do
    GenServer.cast(__MODULE__, {:invalidate, agent_id})
  end

  @doc "Put a file directly into cache (used by tests and bootstrap seeding)."
  def put_file(agent_id, filename, content) do
    :ets.insert(@table, {{:agent, agent_id, filename}, content})
  end

  def put_user_file(agent_id, user_id, filename, content) do
    :ets.insert(@table, {{:user, agent_id, user_id, filename}, content})
  end

  # -- GenServer --

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    seed_bootstrap_files()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:load_agent_file, agent_id, filename}, _from, state) do
    result = ExClaw.StoreSQLite.ContextFile.get_agent_file(agent_id, filename)
    if match?({:ok, _}, result) do
      {:ok, content} = result
      :ets.insert(@table, {{:agent, agent_id, filename}, content})
    end
    {:reply, result, state}
  end

  def handle_call({:load_user_file, agent_id, user_id, filename}, _from, state) do
    result = ExClaw.StoreSQLite.ContextFile.get_user_file(agent_id, user_id, filename)
    if match?({:ok, _}, result) do
      {:ok, content} = result
      :ets.insert(@table, {{:user, agent_id, user_id, filename}, content})
    end
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:invalidate, agent_id}, state) do
    :ets.match_delete(@table, {{:agent, agent_id, :_}, :_})
    {:noreply, state}
  end

  # -- Private --

  @bootstrap_dir :code.priv_dir(:ex_claw) |> List.to_string() |> Path.join("bootstrap")

  defp seed_bootstrap_files do
    case File.ls(@bootstrap_dir) do
      {:ok, files} ->
        Enum.each(files, fn filename ->
          path = Path.join(@bootstrap_dir, filename)
          case File.read(path) do
            {:ok, content} ->
              # Store as "global" template keyed by nil agent (fallback)
              :ets.insert(@table, {{:global_template, filename}, content})
              Logger.debug("[FileRouter] Seeded bootstrap file: #{filename}")

            {:error, _} ->
              :ok
          end
        end)

      {:error, _} ->
        Logger.debug("[FileRouter] No priv/bootstrap/ directory — skipping seed")
    end
  end
end
