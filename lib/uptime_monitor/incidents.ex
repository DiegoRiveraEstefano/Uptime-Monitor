defmodule UptimeMonitor.Incidents do
  @moduledoc """
  The Incidents context. Manages outage states, incident lifecycles, and post-mortem logs.
  """

  import Ecto.Query, warn: false

  alias UptimeMonitor.Repo
  alias UptimeMonitor.Incidents.{Incident, PostMortem}
  alias UptimeMonitor.Monitors.Monitor
  alias UptimeMonitor.Accounts.User

  @doc """
  Logs a monitor failure. If an active open incident already exists, returns it to avoid alert fatigue.
  If none exists, starts a new incident and dispatches alerts.
  """
  @spec report_failure(Monitor.t(), String.t() | nil) :: {:ok, Incident.t()} | {:error, any()}
  def report_failure(%Monitor{} = monitor, _reason) do
    # Check if there is an active incident for this monitor
    query = from i in Incident, where: i.monitor_id == ^monitor.id and i.status == "open", limit: 1
    
    case Repo.one(query) do
      %Incident{} = existing_incident ->
        {:ok, existing_incident}

      nil ->
        # Create a new incident
        attrs = %{
          status: "open",
          opened_at: DateTime.utc_now()
        }

        %Incident{monitor_id: monitor.id, tenant_id: monitor.tenant_id}
        |> Incident.changeset(attrs)
        |> Repo.insert()
        |> case do
          {:ok, incident} ->
            # Dispatch outage alerts asynchronously
            UptimeMonitor.Alerts.dispatch_incident_alert(incident, :opened)
            {:ok, incident}
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Logs a monitor recovery. Resolves any open incident, computes the total downtime, and dispatches recovery alerts.
  """
  @spec report_recovery(Monitor.t()) :: {:ok, Incident.t()} | {:error, :no_active_incident | any()}
  def report_recovery(%Monitor{} = monitor) do
    query = from i in Incident, where: i.monitor_id == ^monitor.id and i.status == "open", limit: 1

    case Repo.one(query) do
      nil ->
        {:error, :no_active_incident}

      incident ->
        resolved_at = DateTime.utc_now()
        downtime = DateTime.diff(resolved_at, incident.opened_at, :second)

        incident
        |> Incident.changeset(%{
          status: "resolved",
          resolved_at: resolved_at,
          downtime_seconds: downtime
        })
        |> Repo.update()
        |> case do
          {:ok, resolved_incident} ->
            # Dispatch recovery alerts asynchronously
            UptimeMonitor.Alerts.dispatch_incident_alert(resolved_incident, :resolved)
            {:ok, resolved_incident}
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # --- Incident Queries ---

  @doc """
  Lists all incidents for a tenant.
  """
  @spec list_incidents(pos_integer()) :: [Incident.t()]
  def list_incidents(tenant_id) do
    Incident
    |> where([i], i.tenant_id == ^tenant_id)
    |> order_by([i], desc: i.opened_at)
    |> preload([:monitor])
    |> Repo.all()
  end

  @doc """
  Gets a single incident scoped to a tenant.
  """
  @spec get_incident!(pos_integer(), pos_integer()) :: Incident.t()
  def get_incident!(tenant_id, id) do
    Incident
    |> where([i], i.id == ^id and i.tenant_id == ^tenant_id)
    |> preload([:monitor, :post_mortem])
    |> Repo.one!()
  end

  # --- Post-Mortems ---

  @doc """
  Creates a post-mortem report for an incident.
  """
  @spec create_post_mortem(User.t(), Incident.t(), map()) :: {:ok, PostMortem.t()} | {:error, any()}
  def create_post_mortem(%User{} = user, %Incident{} = incident, attrs) do
    %PostMortem{incident_id: incident.id, created_by_id: user.id}
    |> PostMortem.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a post-mortem by incident ID.
  """
  @spec get_post_mortem_by_incident(pos_integer()) :: PostMortem.t() | nil
  def get_post_mortem_by_incident(incident_id) do
    Repo.get_by(PostMortem, incident_id: incident_id)
  end
end
