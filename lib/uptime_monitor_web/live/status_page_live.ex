defmodule UptimeMonitorWeb.StatusPageLive do
  @moduledoc """
  Public status page display LiveView.
  """
  use UptimeMonitorWeb, :live_view

  alias UptimeMonitor.{StatusPages, Monitors, Incidents, Metrics}
  import Ecto.Query
  alias UptimeMonitorWeb.UptimeComponents
  alias UptimeMonitorWeb.Layouts

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case StatusPages.get_status_page_by_slug(slug) do
      {:ok, status_page} ->
        if status_page.is_public do
          # Load visible monitors
          all_monitors = Monitors.list_monitors(status_page.tenant_id)

          visible_monitors =
            Enum.filter(all_monitors, fn monitor ->
              monitor.id in status_page.visible_monitor_ids
            end)

          # Fetch details for each monitor
          monitors_with_stats =
            Enum.map(visible_monitors, fn monitor ->
              # Check if monitor has open incident
              query =
                from i in Incidents.Incident,
                  where: i.monitor_id == ^monitor.id and i.status == "open",
                  limit: 1

              has_open_incident = UptimeMonitor.Repo.exists?(query)
              status = if has_open_incident, do: "down", else: "up"

              uptime = Metrics.get_uptime_percentage(monitor, 30)
              latency = Metrics.get_average_latency(monitor, 30)

              %{
                id: monitor.id,
                name: monitor.name,
                url: monitor.url,
                status: status,
                uptime: uptime,
                latency: latency
              }
            end)

          # Evaluate overall system state
          global_status = evaluate_global_status(monitors_with_stats)

          socket =
            socket
            |> assign(:status_page, status_page)
            |> assign(:monitors, monitors_with_stats)
            |> assign(:global_status, global_status)
            |> assign(:error, nil)

          {:ok, socket}
        else
          {:ok, assign(socket, :error, :private)}
        end

      {:error, :not_found} ->
        {:ok, assign(socket, :error, :not_found)}
    end
  end

  defp evaluate_global_status([]) do
    "operational"
  end

  defp evaluate_global_status(monitors) do
    downs = Enum.count(monitors, &(&1.status == "down"))
    total = length(monitors)

    cond do
      downs == 0 -> "operational"
      downs == total -> "major_outage"
      true -> "degraded"
    end
  end
end
