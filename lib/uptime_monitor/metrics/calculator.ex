defmodule UptimeMonitor.Metrics.Calculator do
  @moduledoc """
  Functional module for computing SLA uptime percentages and latency statistics.
  """

  @doc """
  Calculates uptime percentage given total checks and failed checks.
  """
  @spec calculate_uptime(non_neg_integer(), non_neg_integer()) :: float()
  def calculate_uptime(0, _failed), do: 100.0

  def calculate_uptime(total, failed) when total > 0 and failed >= 0 do
    passed = total - failed
    Float.round(passed / total * 100, 4)
  end

  @doc """
  Calculates average latency.
  """
  @spec calculate_average_latency(non_neg_integer(), non_neg_integer()) :: float()
  def calculate_average_latency(0, _total_latency), do: 0.0

  def calculate_average_latency(total, total_latency) when total > 0 and total_latency >= 0 do
    Float.round(total_latency / total, 2)
  end
end
