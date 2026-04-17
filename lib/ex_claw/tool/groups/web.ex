defmodule ExClaw.Tool.Groups.Web do
  @moduledoc "Web tool group — HTTP fetch and web search."

  alias ExClaw.Tool.Metadata

  # Private CIDR ranges blocked by SSRF guard
  @private_cidrs [
    ~r/^10\./,
    ~r/^172\.(1[6-9]|2[0-9]|3[01])\./,
    ~r/^192\.168\./,
    ~r/^127\./,
    ~r/^169\.254\./,
    ~r/^::1$/,
    ~r/^fc00:/,
    ~r/^fd[0-9a-f]{2}:/
  ]

  def tools do
    [
      {%Metadata{
         name: "fetch",
         group: :web,
         description: "Fetch the content of a URL via HTTP GET. Public URLs only.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "url"     => %{"type" => "string"},
             "headers" => %{"type" => "object", "description" => "Optional request headers"}
           },
           "required" => ["url"]
         },
         rate_limit: 20
       }, __MODULE__.Fetch},

      {%Metadata{
         name: "web_search",
         group: :web,
         description: "Search the web and return a list of results with titles, URLs, and snippets.",
         parameters: %{
           "type" => "object",
           "properties" => %{
             "query" => %{"type" => "string"},
             "limit" => %{"type" => "integer", "description" => "Max results (default 5)"}
           },
           "required" => ["query"]
         },
         rate_limit: 10
       }, __MODULE__.WebSearch}
    ]
  end

  defmodule Fetch do
    def execute(%{"url" => url} = input, _ctx) do
      with :ok <- ExClaw.Tool.Groups.Web.check_ssrf(url) do
        headers = Map.get(input, "headers", %{}) |> Map.to_list()
        req = Req.new(headers: headers, receive_timeout: 15_000)
        case Req.get(req, url: url) do
          {:ok, %{status: status, body: body}} when status in 200..299 ->
            text = if is_binary(body), do: body, else: Jason.encode!(body)
            {:ok, String.slice(text, 0, 8_000)}
          {:ok, %{status: status}} ->
            {:error, "fetch: HTTP #{status}"}
          {:error, reason} ->
            {:error, "fetch failed: #{inspect(reason)}"}
        end
      end
    end
  end

  defmodule WebSearch do
    def execute(%{"query" => query} = input, _ctx) do
      limit = Map.get(input, "limit", 5)
      # Try configured search provider; fall back to DuckDuckGo lite
      provider = Application.get_env(:ex_claw, :web_search_provider, :duckduckgo)
      do_search(provider, query, limit)
    end

    defp do_search(:duckduckgo, query, limit) do
      url = "https://api.duckduckgo.com/?q=#{URI.encode(query)}&format=json&no_redirect=1"
      case Req.get(url: url, receive_timeout: 10_000) do
        {:ok, %{status: 200, body: body}} when is_map(body) ->
          results =
            (body["RelatedTopics"] || [])
            |> Enum.take(limit)
            |> Enum.map(fn t ->
              "- #{t["Text"] || ""}\n  #{t["FirstURL"] || ""}"
            end)
            |> Enum.join("\n")
          {:ok, if(results == "", do: "No results found.", else: results)}

        _ ->
          {:ok, "Web search unavailable — configure :web_search_provider in config."}
      end
    end

    defp do_search(_, _query, _limit) do
      {:ok, "Web search provider not configured."}
    end
  end

  @doc false
  def check_ssrf(url) do
    case URI.parse(url) do
      %URI{host: nil} ->
        {:error, "fetch: invalid URL (no host)"}

      %URI{host: host} ->
        if Enum.any?(@private_cidrs, &Regex.match?(&1, host)) do
          {:error, "fetch: SSRF blocked — private/internal address"}
        else
          :ok
        end
    end
  end
end
