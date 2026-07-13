defmodule UptimeMonitor.Alerts do
  @moduledoc """
  The Alerts context. Manages notification settings, in-app alerts, and dispatches external alerts.
  """

  import Ecto.Query, warn: false

  alias UptimeMonitor.Repo
  alias UptimeMonitor.Alerts.{NotificationChannel, PlatformNotification, Adapter}
  alias UptimeMonitor.Accounts.Tenant

  # --- Notification Channel CRUD ---

  @doc """
  Lists active and inactive notification channels for a tenant.
  """
  @spec list_notification_channels(pos_integer()) :: [NotificationChannel.t()]
  def list_notification_channels(tenant_id) do
    NotificationChannel
    |> where([c], c.tenant_id == ^tenant_id)
    |> order_by([c], asc: c.inserted_at)
    |> Repo.all()
  end

  @doc """
  Creates a notification channel.
  """
  @spec create_notification_channel(Tenant.t(), map()) ::
          {:ok, NotificationChannel.t()} | {:error, any()}
  def create_notification_channel(%Tenant{} = tenant, attrs) do
    %NotificationChannel{tenant_id: tenant.id}
    |> NotificationChannel.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a notification channel.
  """
  @spec delete_notification_channel(Tenant.t(), pos_integer()) ::
          {:ok, NotificationChannel.t()} | {:error, any()}
  def delete_notification_channel(%Tenant{} = tenant, id) do
    case Repo.get_by(NotificationChannel, id: id, tenant_id: tenant.id) do
      nil -> {:error, :not_found}
      channel -> Repo.delete(channel)
    end
  end

  # --- Platform In-App Notifications ---

  @doc """
  Lists unread and read platform alerts in-app for a tenant.
  """
  @spec list_platform_notifications(pos_integer()) :: [PlatformNotification.t()]
  def list_platform_notifications(tenant_id) do
    PlatformNotification
    |> where([n], n.tenant_id == ^tenant_id)
    |> order_by([n], desc: n.inserted_at)
    |> Repo.all()
  end

  @doc """
  Inserts an in-app alert log directly.
  """
  @spec create_platform_notification(pos_integer(), map()) ::
          {:ok, PlatformNotification.t()} | {:error, any()}
  def create_platform_notification(tenant_id, attrs) do
    %PlatformNotification{tenant_id: tenant_id}
    |> PlatformNotification.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Marks an in-app alert as read.
  """
  @spec mark_notification_as_read(pos_integer(), pos_integer()) ::
          {:ok, PlatformNotification.t()} | {:error, any()}
  def mark_notification_as_read(tenant_id, id) do
    case Repo.get_by(PlatformNotification, id: id, tenant_id: tenant_id) do
      nil ->
        {:error, :not_found}

      notification ->
        notification
        |> Ecto.Changeset.change(read: true)
        |> Repo.update()
    end
  end

  # --- Asynchronous Alerts Dispatcher Pipeline ---

  @doc """
  Dispatches an incident alert asynchronously. 
  Fetches active channels and processes delivery using Task.async_stream/3.
  """
  @spec dispatch_incident_alert(UptimeMonitor.Incidents.Incident.t(), :opened | :resolved) ::
          {:ok, pid()}
  def dispatch_incident_alert(incident, event_type) do
    # Run the alerts routing inside an isolated task to prevent blocking the caller worker
    Task.start(fn ->
      incident = Repo.preload(incident, :monitor)

      event = %{
        incident: incident,
        monitor: incident.monitor,
        type: event_type
      }

      # Retrieve active notification integrations
      channels =
        NotificationChannel
        |> where([c], c.tenant_id == ^incident.tenant_id and c.active == true)
        |> Repo.all()

      # Concurrently send alerts to channels with back-pressure constraints
      channels
      |> Task.async_stream(
        fn channel ->
          case Adapter.deliver(channel, event) do
            {:ok, _} ->
              :ok

            {:error, reason} ->
              # In production, we'd log failures via Logger
              {:error, reason}
          end
        end,
        timeout: :infinity,
        on_timeout: :kill_task
      )
      |> Stream.run()
    end)
  end
end
