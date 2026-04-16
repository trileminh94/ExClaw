defmodule ExClaw.Store.CronStore do
  @moduledoc "Behaviour for cron job persistence."

  @type job_id :: String.t()
  @type job :: map()
  @type attrs :: map()

  @callback create_cron_job(attrs()) :: {:ok, job()} | {:error, term()}
  @callback get_cron_job(job_id()) :: {:ok, job()} | {:error, :not_found}
  @callback list_cron_jobs(opts :: map()) :: {:ok, [job()]}
  @callback update_cron_job(job_id(), attrs()) :: {:ok, job()} | {:error, term()}
  @callback delete_cron_job(job_id()) :: :ok | {:error, term()}
  @callback append_run_log(attrs()) :: {:ok, map()} | {:error, term()}
  @callback list_run_logs(job_id(), limit :: non_neg_integer()) :: {:ok, [map()]}
end
