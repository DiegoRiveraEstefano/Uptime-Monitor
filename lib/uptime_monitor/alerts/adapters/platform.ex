defmodule UptimeMonitor.Alerts.Adapters.Platform do
  @moduledoc """
  Inserts in-app alerts directly into the platform notifications center.
  """
  alias UptimeMonitor.Alerts

  @spec deliver(UptimeMonitor.Alerts.NotificationChannel.t(), map()) :: {:ok, term()} | {:error, term()}
  def deliver(channel, event) do
    monitor = event.monitor
    incident = event.incident
    event_type = event.type

    title =
      case event_type do
        :opened -> "Outage: #{monitor.name}"
        :resolved -> "Recovery: #{monitor.name}"
      end

    message =
      case event_type do
        :opened -> "Endpoint #{monitor.url} failed check. Outage registered."
        :resolved -> "Endpoint #{monitor.url} is online again. Downtime: #{incident.downtime_seconds}s."
      end

    Alerts.create_platform_notification(channel.tenant_id, %{
      title: title,
      message: message,
      read: false
    })
  end
end
