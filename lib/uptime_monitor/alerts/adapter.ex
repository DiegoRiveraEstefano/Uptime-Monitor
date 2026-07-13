defprotocol UptimeMonitor.Alerts.Adapter do
  @moduledoc """
  Protocol for alerting notification channels.
  """

  @doc """
  Delivers an incident notification using the given channel configuration and event payload.
  """
  @spec deliver(struct(), event :: map()) :: {:ok, term()} | {:error, term()}
  def deliver(channel, event)
end

defimpl UptimeMonitor.Alerts.Adapter, for: UptimeMonitor.Alerts.NotificationChannel do
  @spec deliver(UptimeMonitor.Alerts.NotificationChannel.t(), map()) ::
          {:ok, term()} | {:error, term()}
  def deliver(channel, event) do
    case channel.type do
      "platform" -> UptimeMonitor.Alerts.Adapters.Platform.deliver(channel, event)
      "email" -> UptimeMonitor.Alerts.Adapters.Email.deliver(channel, event)
      "slack" -> UptimeMonitor.Alerts.Adapters.Slack.deliver(channel, event)
      "webhook" -> UptimeMonitor.Alerts.Adapters.Webhook.deliver(channel, event)
      _ -> {:error, :unsupported_channel_type}
    end
  end
end
