defmodule UptimeMonitor.Incidents do
  @moduledoc """
  Temporary stub for the Incidents context to allow compilation and testing of the Monitors domain.
  This will be fully implemented in the next steps.
  """

  def report_failure(_monitor, _reason) do
    {:ok, :logged}
  end

  def report_recovery(_monitor) do
    {:ok, :logged}
  end
end
