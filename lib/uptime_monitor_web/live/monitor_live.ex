defmodule UptimeMonitorWeb.MonitorLive do
  @moduledoc """
  Detailed statistics and settings page for a single monitor.
  """
  use UptimeMonitorWeb, :live_view

  alias UptimeMonitor.{Accounts, Monitors, Incidents, Metrics}
  import Ecto.Query
  alias UptimeMonitorWeb.UptimeComponents
  alias UptimeMonitorWeb.Layouts

  @impl true
  def mount(%{"tenant_slug" => slug, "id" => id}, session, socket) do
    case get_current_context(session, slug) do
      {:ok, user, tenant, membership} ->
        monitor_id = String.to_integer(id)

        case Monitors.get_monitor(tenant.id, monitor_id) do
          {:ok, monitor} ->
            # Fetch stats
            uptime = Metrics.get_uptime_percentage(monitor, 30)
            latency = Metrics.get_average_latency(monitor, 30)

            # Fetch check results and preloaded incidents
            check_results =
              UptimeMonitor.Repo.all(
                from r in Monitors.CheckResult,
                  where: r.monitor_id == ^monitor.id,
                  order_by: [desc: r.inserted_at],
                  limit: 15
              )

            incidents =
              UptimeMonitor.Repo.all(
                from i in Incidents.Incident,
                  where: i.monitor_id == ^monitor.id,
                  order_by: [desc: i.opened_at],
                  limit: 5
              )

            # Prepare edit changeset
            edit_form = Phoenix.Component.to_form(Monitors.Monitor.changeset(monitor, %{}))

            socket =
              socket
              |> assign(:current_user, user)
              |> assign(:current_tenant, tenant)
              |> assign(:current_role, membership.role)
              |> assign(:monitor, monitor)
              |> assign(:uptime, uptime)
              |> assign(:latency, latency)
              |> assign(:check_results, check_results)
              |> assign(:incidents, incidents)
              |> assign(:edit_form, edit_form)
              |> assign(:show_edit_form, false)

            {:ok, socket}

          {:error, :not_found} ->
            {:ok, redirect(socket, to: ~p"/org/#{tenant.slug}")}
        end

      {:error, _} ->
        {:ok, redirect(socket, to: "/login")}
    end
  end

  @impl true
  def handle_event("toggle_edit_form", _, socket) do
    {:noreply, assign(socket, :show_edit_form, !socket.assigns.show_edit_form)}
  end

  @impl true
  def handle_event("update_monitor", %{"monitor" => params}, socket) do
    tenant = socket.assigns.current_tenant
    monitor = socket.assigns.monitor

    case Monitors.update_monitor(tenant, monitor, params) do
      {:ok, updated} ->
        # Reload stats
        uptime = Metrics.get_uptime_percentage(updated, 30)
        latency = Metrics.get_average_latency(updated, 30)

        socket =
          socket
          |> assign(:monitor, updated)
          |> assign(:uptime, uptime)
          |> assign(:latency, latency)
          |> assign(:show_edit_form, false)
          |> assign(
            :edit_form,
            Phoenix.Component.to_form(Monitors.Monitor.changeset(updated, %{}))
          )
          |> put_flash(:info, "Monitor configuration updated successfully.")

        {:noreply, socket}

      {:error, changeset} ->
        form = Phoenix.Component.to_form(changeset)
        {:noreply, assign(socket, edit_form: form)}
    end
  end

  @impl true
  def handle_event("delete_monitor", _, socket) do
    tenant = socket.assigns.current_tenant
    monitor = socket.assigns.monitor

    case Monitors.delete_monitor(tenant, monitor) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Monitor deleted.")
         |> push_navigate(to: ~p"/org/#{tenant.slug}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not delete monitor: #{inspect(reason)}")}
    end
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
end
