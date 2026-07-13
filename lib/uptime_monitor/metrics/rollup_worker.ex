defmodule UptimeMonitor.Metrics.RollupWorker do
  @moduledoc """
  Background GenServer that consolidates checks history into rollups and runs data pruning.
  """
  use GenServer

  import Ecto.Query, warn: false

  alias UptimeMonitor.Repo
  alias UptimeMonitor.Monitors.CheckResult
  alias UptimeMonitor.Metrics.{HourlyRollup, DailyRollup}

  # --- Client API ---

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  # --- Server Callbacks ---

  @impl GenServer
  def init(init_arg) do
    # Schedule first aggregation checker task in 1 minute
    Process.send_after(self(), :check_rollup, :timer.minutes(1))
    {:ok, init_arg}
  end

  @impl GenServer
  def handle_info(:check_rollup, state) do
    now = DateTime.utc_now()

    # Run rollups
    run_aggregations(now)

    # Re-schedule check every hour
    Process.send_after(self(), :check_rollup, :timer.hours(1))
    {:noreply, state}
  end

  # --- Execution Logic ---

  @doc """
  Runs aggregations for the current period and cleans up old data.
  """
  @spec run_aggregations(DateTime.t()) :: :ok
  def run_aggregations(now) do
    # 1. Aggregate previous hour checks
    previous_hour = DateTime.add(now, -3600, :second) |> truncate_to_hour()
    perform_hourly_rollup(previous_hour)

    # 2. If it's the start of the day (e.g. 00:00 - 01:00 UTC), compile daily rollup & prune data
    if now.hour == 0 do
      previous_day = DateTime.to_date(now) |> Date.add(-1)
      perform_daily_rollup(previous_day)
      prune_expired_records()
    end

    :ok
  end

  @doc """
  Performs hourly log aggregations grouped by monitor.
  """
  @spec perform_hourly_rollup(DateTime.t()) :: :ok
  def perform_hourly_rollup(hour) do
    start_time = hour
    end_time = DateTime.add(hour, 3599, :second)

    query =
      from r in CheckResult,
        where: r.inserted_at >= ^start_time and r.inserted_at <= ^end_time,
        group_by: r.monitor_id,
        select: {
          r.monitor_id,
          count(r.id),
          sum(fragment("CASE WHEN ? = 'down' THEN 1 ELSE 0 END", r.status)),
          sum(r.latency_ms)
        }

    Repo.all(query)
    |> Enum.each(fn {monitor_id, total, failed, total_latency} ->
      # Use insert with on_conflict override to prevent duplicate errors
      %HourlyRollup{}
      |> HourlyRollup.changeset(%{
        monitor_id: monitor_id,
        hour: start_time,
        total_checks: total || 0,
        failed_checks: failed || 0,
        total_latency_ms: total_latency || 0
      })
      |> Repo.insert(
        on_conflict: {:replace, [:total_checks, :failed_checks, :total_latency_ms]},
        conflict_target: [:monitor_id, :hour]
      )
    end)

    :ok
  end

  @doc """
  Performs daily rollups aggregates from hourly stats.
  """
  @spec perform_daily_rollup(Date.t()) :: :ok
  def perform_daily_rollup(date) do
    # Define date bounds in UTC DateTime
    start_time = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_time = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    query =
      from h in HourlyRollup,
        where: h.hour >= ^start_time and h.hour <= ^end_time,
        group_by: h.monitor_id,
        select: {
          h.monitor_id,
          sum(h.total_checks),
          sum(h.failed_checks),
          sum(h.total_latency_ms)
        }

    Repo.all(query)
    |> Enum.each(fn {monitor_id, total, failed, total_latency} ->
      %DailyRollup{}
      |> DailyRollup.changeset(%{
        monitor_id: monitor_id,
        date: date,
        total_checks: total || 0,
        failed_checks: failed || 0,
        total_latency_ms: total_latency || 0
      })
      |> Repo.insert(
        on_conflict: {:replace, [:total_checks, :failed_checks, :total_latency_ms]},
        conflict_target: [:monitor_id, :date]
      )
    end)

    :ok
  end

  @doc """
  Deletes checks older than 14 days and hourly rollups older than 90 days.
  """
  @spec prune_expired_records() :: :ok
  def prune_expired_records do
    # Prune raw checks > 14 days
    cutoff_checks = DateTime.utc_now() |> DateTime.add(-14 * 86400, :second)
    Repo.delete_all(from r in CheckResult, where: r.inserted_at < ^cutoff_checks)

    # Prune hourly rollups > 90 days
    cutoff_hourly = DateTime.utc_now() |> DateTime.add(-90 * 86400, :second)
    Repo.delete_all(from h in HourlyRollup, where: h.hour < ^cutoff_hourly)

    :ok
  end

  defp truncate_to_hour(%DateTime{} = datetime) do
    %DateTime{datetime | minute: 0, second: 0, microsecond: {0, 0}}
  end
end
