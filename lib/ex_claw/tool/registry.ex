defmodule ExClaw.Tool.Registry do
  @moduledoc """
  ETS-backed tool registry.

  Tools register themselves (or are registered at startup) with a
  `%Tool.Metadata{}` and an implementation module. The registry provides:
  - `register/2`    — write through the GenServer (serialized)
  - `lookup/1`      — direct concurrent ETS read
  - `list/0`        — all registered tools
  - `definitions/0` — LLM tool definitions for all registered tools

  Implementation modules must export:
      @spec execute(input :: map(), context :: map()) :: {:ok, String.t()} | {:error, term()}

  All built-in tools are registered at startup from the tool group modules.
  """
  use GenServer

  alias ExClaw.Tool.Metadata

  @table :tool_registry

  # -- Client API --

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Register a tool. Overwrites any existing entry with the same name."
  @spec register(Metadata.t(), module()) :: :ok
  def register(%Metadata{} = meta, impl_module) do
    GenServer.call(__MODULE__, {:register, meta, impl_module})
  end

  @doc "Look up a tool by name. Returns `{:ok, {metadata, impl_module}}` or `{:error, :not_found}`."
  @spec lookup(String.t()) :: {:ok, {Metadata.t(), module()}} | {:error, :not_found}
  def lookup(name) when is_binary(name) do
    case :ets.lookup(@table, name) do
      [{^name, meta, impl}] -> {:ok, {meta, impl}}
      [] -> {:error, :not_found}
    end
  end

  @doc "Returns all registered tool names."
  @spec list() :: [String.t()]
  def list do
    :ets.tab2list(@table) |> Enum.map(fn {name, _meta, _impl} -> name end)
  end

  @doc "Returns all LLM tool definitions for registered tools."
  @spec definitions() :: [map()]
  def definitions do
    :ets.tab2list(@table)
    |> Enum.map(fn {_name, meta, _impl} -> Metadata.to_llm_definition(meta) end)
  end

  @doc "Returns definitions for a specific list of tool names (or all if nil)."
  @spec definitions_for([String.t()] | nil) :: [map()]
  def definitions_for(nil), do: definitions()
  def definitions_for(names) when is_list(names) do
    Enum.flat_map(names, fn name ->
      case lookup(name) do
        {:ok, {meta, _}} -> [Metadata.to_llm_definition(meta)]
        {:error, _} -> []
      end
    end)
  end

  # -- GenServer --

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    register_builtin_tools()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, meta, impl}, _from, state) do
    :ets.insert(@table, {meta.name, meta, impl})
    {:reply, :ok, state}
  end

  # -- Private --

  defp register_builtin_tools do
    groups = [
      ExClaw.Tool.Groups.FS,
      ExClaw.Tool.Groups.Runtime,
      ExClaw.Tool.Groups.Web,
      ExClaw.Tool.Groups.Memory,
      ExClaw.Tool.Groups.Delegation,
      ExClaw.Tool.Groups.Teams
    ]

    Enum.each(groups, fn group_module ->
      Enum.each(group_module.tools(), fn {meta, impl} ->
        :ets.insert(@table, {meta.name, meta, impl})
      end)
    end)
  end
end
