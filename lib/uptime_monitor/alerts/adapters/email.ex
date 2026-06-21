defmodule UptimeMonitor.Alerts.Adapters.Email do
  @moduledoc """
  Sends email alerts using Swoosh.
  """
  import Swoosh.Email

  alias UptimeMonitor.Mailer

  @spec deliver(UptimeMonitor.Alerts.NotificationChannel.t(), map()) :: {:ok, term()} | {:error, term()}
  def deliver(channel, event) do
    to_email = Map.get(channel.config, "to")
    monitor = event.monitor
    incident = event.incident
    event_type = event.type

    subject =
      case event_type do
        :opened -> "🚨 ALERT: Outage detected for #{monitor.name}"
        :resolved -> "✅ RECOVERY: #{monitor.name} is back online"
      end

    body =
      case event_type do
        :opened ->
          """
          Outage Detected!
          ----------------
          Monitor: #{monitor.name}
          URL: #{monitor.url}
          Incident started at: #{incident.opened_at}
          """
        :resolved ->
          """
          Service Recovered!
          ------------------
          Monitor: #{monitor.name}
          URL: #{monitor.url}
          Downtime duration: #{incident.downtime_seconds} seconds
          Resolved at: #{incident.resolved_at}
          """
      end

    new()
    |> to(to_email)
    |> from({"UptimeMonitor Alerts", "alerts@uptime_monitor.com"})
    |> subject(subject)
    |> text_body(body)
    |> Mailer.deliver()
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
      # If Swoosh returns a transaction map
      _ -> {:ok, :sent}
    end
  end
end
