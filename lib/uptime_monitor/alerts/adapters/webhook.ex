defmodule UptimeMonitor.Alerts.Adapters.Webhook do
  @moduledoc """
  Dispatches JSON alert payloads to custom webhook endpoints.
  """

  @spec deliver(UptimeMonitor.Alerts.NotificationChannel.t(), map()) ::
          {:ok, term()} | {:error, term()}
  def deliver(channel, event) do
    url = Map.get(channel.config, "url")
    monitor = event.monitor
    incident = event.incident
    event_type = event.type

    payload = %{
      event: event_type,
      monitor: %{
        id: monitor.id,
        name: monitor.name,
        url: monitor.url
      },
      incident: %{
        id: incident.id,
        opened_at: incident.opened_at,
        resolved_at: incident.resolved_at,
        downtime_seconds: incident.downtime_seconds
      }
    }

    case Req.post(url, json: payload, connect_options: [timeout: 5000], receive_timeout: 5000) do
      {:ok, %Req.Response{status: status}} when status >= 200 and status < 300 ->
        {:ok, :dispatched}

      {:ok, %Req.Response{status: status}} ->
        {:error, "Webhook returned status: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
