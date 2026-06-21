defmodule UptimeMonitor.Metrics do
  @moduledoc """
  The Metrics context. Interfaces with hourly and daily rollups to retrieve SLA statistics.
  """

  import Ecto.Query, warn: false

  alias UptimeMonitor.Repo
  alias UptimeMonitor.Metrics.{DailyRollup, Calculator}
  alias UptimeMonitor.Monitors.Monitor

  @doc """
  Calculates the uptime percentage for a monitor over the last N days.
  """
  @spec get_uptime_percentage(Monitor.t(), pos_integer()) :: float()
  def get_uptime_percentage(%Monitor{} = monitor, days) when is_integer(days) do
    cutoff_date = Date.utc_today() |> Date.add(-days)

    query =
      from d in DailyRollup,
      where: d.monitor_id == ^monitor.id and d.date >= ^cutoff_date,
      select: {sum(d.total_checks), sum(d.failed_checks)}

    case Repo.one(query) do
      {total, failed} when not is_nil(total) ->
        Calculator.calculate_uptime(total, failed)
      _ ->
        100.0
    end
  end

  @doc """
  Calculates the average latency for a monitor over the last N days.
  """
  @spec get_average_latency(Monitor.t(), pos_integer()) :: float()
  def get_average_latency(%Monitor{} = monitor, days) when is_integer(days) do
    cutoff_date = Date.utc_today() |> Date.add(-days)

    query =
      from d in DailyRollup,
      where: d.monitor_id == ^monitor.id and d.date >= ^cutoff_date,
      select: {sum(d.total_checks), sum(d.total_latency_ms)}

    case Repo.one(query) do
      {total, total_latency} when not is_nil(total) ->
        Calculator.calculate_average_latency(total, total_latency)
      _ ->
        0.0
    end
  end
end
