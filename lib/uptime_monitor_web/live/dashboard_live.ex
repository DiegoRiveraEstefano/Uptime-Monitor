defmodule UptimeMonitorWeb.DashboardLive do
  @moduledoc """
  Main tenant-scoped dashboard workspace.
  """
  use UptimeMonitorWeb, :live_view

  alias UptimeMonitor.{Accounts, Monitors, Alerts, Incidents}
  alias UptimeMonitorWeb.UptimeComponents
  alias UptimeMonitorWeb.Layouts

  @impl true
  def mount(%{"tenant_slug" => slug}, session, socket) do
    case get_current_context(session, slug) do
      {:ok, user, tenant, membership} ->
        # Fetch initial dataset
        monitors = Monitors.list_monitors(tenant.id)
        incidents = Incidents.list_incidents(tenant.id)
        unread_notifications = Alerts.list_platform_notifications(tenant.id) |> Enum.filter(&(!&1.read))

        # Calculate general stats
        {sla, avg_latency} = calculate_global_stats(monitors)

        # Set up monitor creation form
        new_monitor_form = Phoenix.Component.to_form(%{"name" => "", "url" => "", "interval_seconds" => "60"}, as: :monitor)

        socket =
          socket
          |> assign(:current_user, user)
          |> assign(:current_tenant, tenant)
          |> assign(:current_role, membership.role)
          |> assign(:global_sla, sla)
          |> assign(:avg_latency, avg_latency)
          |> assign(:incidents, incidents)
          |> assign(:unread_notifications, unread_notifications)
          |> assign(:show_create_form, false)
          |> assign(:new_monitor_form, new_monitor_form)
          |> stream(:monitors, monitors)

        {:ok, socket}

      {:error, :unauthenticated} ->
        {:ok, redirect(socket, to: "/login")}

      {:error, _} ->
        {:ok, redirect(socket, to: "/login")}
    end
  end

  @impl true
  def handle_event("toggle_create_form", _, socket) do
    {:noreply, assign(socket, :show_create_form, !socket.assigns.show_create_form)}
  end

  @impl true
  def handle_event("save_monitor", %{"monitor" => params}, socket) do
    tenant = socket.assigns.current_tenant

    case Monitors.create_monitor(tenant, params) do
      {:ok, monitor} ->
        # Recalculate metrics
        monitors = Monitors.list_monitors(tenant.id)
        {sla, avg_latency} = calculate_global_stats(monitors)

        socket =
          socket
          |> stream_insert(:monitors, monitor)
          |> assign(:show_create_form, false)
          |> assign(:global_sla, sla)
          |> assign(:avg_latency, avg_latency)
          |> put_flash(:info, "Monitor created successfully!")

        {:noreply, socket}

      {:error, changeset} ->
        form = Phoenix.Component.to_form(changeset)
        {:noreply, assign(socket, new_monitor_form: form)}
    end
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    tenant = socket.assigns.current_tenant
    
    case Monitors.get_monitor(tenant.id, String.to_integer(id)) do
      {:ok, monitor} ->
        # Toggle status
        target_state = !monitor.active
        {:ok, updated} = Monitors.update_monitor(tenant, monitor, %{active: target_state})

        {:noreply,
         socket
         |> stream_insert(:monitors, updated)
         |> put_flash(:info, "Monitor status updated.")}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("mark_read", %{"id" => id}, socket) do
    tenant = socket.assigns.current_tenant
    {:ok, _} = Alerts.mark_notification_as_read(tenant.id, String.to_integer(id))
    
    unread = Alerts.list_platform_notifications(tenant.id) |> Enum.filter(&(!&1.read))
    {:noreply, assign(socket, :unread_notifications, unread)}
  end

  # --- Authorization context helper ---
  defp get_current_context(session, slug) do
    user_id = session["user_id"]

    if user_id do
      user = Accounts.get_user!(user_id)
      tenant = Accounts.get_tenant_by_slug(slug)

      if tenant do
        case Accounts.get_membership(tenant.id, user.id) do
          nil -> {:error, :unauthorized}
          membership -> {:ok, user, tenant, membership}
        end
      else
        {:error, :not_found}
      end
    else
      {:error, :unauthenticated}
    end
  end

  defp calculate_global_stats([]) do
    {"100.00", 0}
  end

  defp calculate_global_stats(monitors) do
    # Calculate simple mockup dashboard statistics based on loaded monitors SLAs
    total_sla =
      Enum.reduce(monitors, 0.0, fn monitor, acc ->
        acc + UptimeMonitor.Metrics.get_uptime_percentage(monitor, 30)
      end)

    total_latency =
      Enum.reduce(monitors, 0.0, fn monitor, acc ->
        acc + UptimeMonitor.Metrics.get_average_latency(monitor, 30)
      end)

    count = length(monitors)
    sla_percentage = Float.round(total_sla / count, 2)
    avg_lat = round(total_latency / count)

    {"#{sla_percentage}", avg_lat}
  end
end
