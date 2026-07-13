defmodule UptimeMonitor.Alerts.Adapters.Slack do
  @moduledoc """
  Dispatches alert notifications to Slack channel webhooks.
  """

  @spec deliver(UptimeMonitor.Alerts.NotificationChannel.t(), map()) ::
          {:ok, term()} | {:error, term()}
  def deliver(channel, event) do
    webhook_url = Map.get(channel.config, "webhook_url")
    monitor = event.monitor
    incident = event.incident
    event_type = event.type

    message =
      case event_type do
        :opened ->
          "🚨 *Outage Detected!* \n*Monitor:* #{monitor.name} (#{monitor.url}) is *DOWN*.\n*Opened At:* #{incident.opened_at}"

        :resolved ->
          "✅ *Service Recovered!* \n*Monitor:* #{monitor.name} is *UP*.\n*Downtime:* #{incident.downtime_seconds} seconds."
      end

    payload = %{text: message}

    case Req.post(webhook_url,
           json: payload,
           connect_options: [timeout: 5000],
           receive_timeout: 5000
         ) do
      {:ok, %Req.Response{status: status}} when status >= 200 and status < 300 ->
        {:ok, :dispatched}

      {:ok, %Req.Response{status: status}} ->
        {:error, "Slack webhook returned status: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
