defmodule ExClaw.Tool.Groups.Memory do
  @moduledoc "Memory tool group — store, search, and expand memory documents."

  alias ExClaw.Tool.Metadata
  alias ExClaw.StoreSQLite.Memory, as: MemStore

  def tools do
    [
      {%Metadata{
         name: "memory_store",
         group: :memory,
         description: "Store a piece of information in long-term memory.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "content"    => %{"type" => "string", "description" => "Content to store"},
             "type"       => %{"type" => "string",
                               "enum" => ["episodic", "semantic"],
                               "description" => "Memory type (default: episodic)"},
             "tags"       => %{"type" => "array", "items" => %{"type" => "string"}}
           },
           "required" => ["content"]
         }
       }, __MODULE__.MemoryStore},

      {%Metadata{
         name: "memory_search",
         group: :memory,
         description: "Search long-term memory for relevant documents.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "query" => %{"type" => "string"},
             "limit" => %{"type" => "integer", "description" => "Max results (default 5)"}
           },
           "required" => ["query"]
         }
       }, __MODULE__.MemorySearch},

      {%Metadata{
         name: "memory_expand",
         group: :memory,
         description: "Retrieve the full content of a specific memory document by ID.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "id" => %{"type" => "string", "description" => "Memory document ID"}
           },
           "required" => ["id"]
         }
       }, __MODULE__.MemoryExpand}
    ]
  end

  defmodule MemoryStore do
    def execute(%{"content" => content} = input, ctx) do
      type = Map.get(input, "type", "episodic")
      tags = Map.get(input, "tags", [])

      attrs = %{
        user_id:   Map.get(ctx, :user_id),
        agent_id:  Map.get(ctx, :agent_id),
        tenant_id: Map.get(ctx, :tenant_id),
        type:      type,
        content:   content,
        tags:      tags
      }

      case MemStore.create_document(attrs) do
        {:ok, doc} -> {:ok, "Memory stored with ID: #{doc.id}"}
        {:error, reason} -> {:error, "memory_store failed: #{inspect(reason)}"}
      end
    end
  end

  defmodule MemorySearch do
    def execute(%{"query" => query} = input, ctx) do
      limit = Map.get(input, "limit", 5)
      user_id = Map.get(ctx, :user_id)
      agent_id = Map.get(ctx, :agent_id)

      case MemStore.search_documents(query, %{user_id: user_id, agent_id: agent_id, limit: limit}) do
        {:ok, []} ->
          {:ok, "No memories found for: #{query}"}

        {:ok, docs} ->
          result =
            docs
            |> Enum.map(fn d ->
              "ID: #{d.id} [#{d.type}]\n#{String.slice(d.content, 0, 300)}"
            end)
            |> Enum.join("\n\n---\n\n")
          {:ok, result}

        {:error, reason} ->
          {:error, "memory_search failed: #{inspect(reason)}"}
      end
    end
  end

  defmodule MemoryExpand do
    def execute(%{"id" => id}, _ctx) do
      case MemStore.get_document(id) do
        {:ok, doc} -> {:ok, doc.content}
        {:error, :not_found} -> {:error, "Memory document #{id} not found"}
        {:error, reason} -> {:error, inspect(reason)}
      end
    end
  end
end
