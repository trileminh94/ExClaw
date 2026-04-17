defmodule ExClaw.Tool.DenyPatterns do
  @moduledoc """
  Shell command deny-pattern groups.

  Ten groups covering the most dangerous shell idioms. Each group is a map
  with :name, :reason, and :patterns (compiled regexes).

  Checked by Tool.Executor before running any :runtime group tool.
  """

  @groups [
    %{name: :rm_rf,
      reason: "recursive deletion",
      patterns: [~r/rm\s+-[^\s]*r/i, ~r/rm\s+--recursive/i]},

    %{name: :curl_pipe,
      reason: "curl/wget piped to shell",
      patterns: [~r/curl[^|]+\|\s*(ba|z|da)?sh/i, ~r/wget[^|]+\|\s*(ba|z|da)?sh/i]},

    %{name: :fork_bomb,
      reason: "fork bomb / process flood",
      patterns: [~r/:\s*\(\s*\)\s*\{/, ~r/while\s+true.*do.*done/i]},

    %{name: :privilege_escalation,
      reason: "privilege escalation",
      patterns: [~r/\bsudo\b/, ~r/\bsu\s+-/, ~r/\bchmod\s+[0-7]*[46][0-7][0-7].*s/i]},

    %{name: :disk_wipe,
      reason: "disk wipe / dd overwrite",
      patterns: [~r/dd\s+if=\/dev\/(zero|urandom|null).*of=\/dev/i, ~r/mkfs\.\w+\s+\/dev/i]},

    %{name: :network_scan,
      reason: "network scanning",
      patterns: [~r/\bnmap\b/i, ~r/\bmasscan\b/i, ~r/\bzmap\b/i]},

    %{name: :path_traversal,
      reason: "path traversal in shell",
      patterns: [~r/\.\.[\/\\]\.\.[\/\\]/]},

    %{name: :crontab_write,
      reason: "writing to crontab",
      patterns: [~r/crontab\s+-[el]/i, ~r/>\s*\/etc\/cron/i]},

    %{name: :hosts_write,
      reason: "modifying /etc/hosts or /etc/passwd",
      patterns: [~r/>\s*\/etc\/(hosts|passwd|shadow|sudoers)/i]},

    %{name: :process_kill_all,
      reason: "kill all processes",
      patterns: [~r/killall\s+-[0-9]*\s*(9|KILL)\s*$/i, ~r/pkill\s+-9\s+\./i]}
  ]

  @doc """
  Check a command string against all deny groups.

  Returns `:ok` or `{:denied, group_name, reason}` for the first match.
  """
  @spec check(String.t()) :: :ok | {:denied, atom(), String.t()}
  def check(command) when is_binary(command) do
    Enum.find_value(@groups, :ok, fn group ->
      if Enum.any?(group.patterns, &Regex.match?(&1, command)) do
        {:denied, group.name, group.reason}
      end
    end)
  end

  @doc "Returns all deny groups (for documentation/testing)."
  def groups, do: @groups
end
