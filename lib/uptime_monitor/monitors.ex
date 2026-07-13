defmodule UptimeMonitor.Monitors do
  @moduledoc """
  The Monitors context. Handles database CRUD, execution queries, and schedules registrations with the engine.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias UptimeMonitor.Repo
  alias UptimeMonitor.Monitors.{Monitor, Heartbeat, CheckResult}
  alias UptimeMonitor.Accounts.Tenant

  # --- Active Monitor CRUD & Engine Integration ---

  @doc """
  Returns the list of monitors scoped to a tenant.
  """
  @spec list_monitors(pos_integer()) :: [Monitor.t()]
  def list_monitors(tenant_id) do
    Monitor
    |> where([m], m.tenant_id == ^tenant_id)
    |> order_by([m], desc: m.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single monitor scoped to a tenant.
  """
  @spec get_monitor(pos_integer(), pos_integer()) :: {:ok, Monitor.t()} | {:error, :not_found}
  def get_monitor(tenant_id, id) do
    case Repo.one(from m in Monitor, where: m.id == ^id and m.tenant_id == ^tenant_id) do
      nil -> {:error, :not_found}
      monitor -> {:ok, monitor}
    end
  end

  @doc """
  Returns all active monitors globally. Used by the OTP Engine at system startup.
  """
  @spec list_active_monitors() :: [Monitor.t()]
  def list_active_monitors do
    Repo.all(from m in Monitor, where: m.active == true)
  end

  @doc """
  Creates a monitor and registers it with the engine.
  """
  @spec create_monitor(Tenant.t(), map()) :: {:ok, Monitor.t()} | {:error, any()}
  def create_monitor(%Tenant{} = tenant, attrs) do
    Multi.new()
    |> Multi.insert(:monitor, Monitor.changeset(%Monitor{tenant_id: tenant.id}, attrs))
    |> Multi.run(:engine_registration, fn _repo, %{monitor: monitor} ->
      if monitor.active do
        case UptimeMonitor.Monitors.Engine.register(monitor) do
          :ok -> {:ok, monitor}
          {:error, reason} -> {:error, reason}
        end
      else
        {:ok, monitor}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{monitor: monitor}} -> {:ok, monitor}
      {:error, _failed_step, error, _changes} -> {:error, error}
    end
  end

  @doc """
  Updates a monitor and restarts its worker process.
  """
  @spec update_monitor(Tenant.t(), Monitor.t(), map()) :: {:ok, Monitor.t()} | {:error, any()}
  def update_monitor(%Tenant{} = tenant, %Monitor{} = monitor, attrs) do
    if monitor.tenant_id == tenant.id do
      Multi.new()
      |> Multi.update(:monitor, Monitor.changeset(monitor, attrs))
      |> Multi.run(:engine_update, fn _repo, %{monitor: updated_monitor} ->
        # Deregister old worker and register new one if active
        UptimeMonitor.Monitors.Engine.deregister(monitor)

        if updated_monitor.active do
          case UptimeMonitor.Monitors.Engine.register(updated_monitor) do
            :ok -> {:ok, updated_monitor}
            {:error, reason} -> {:error, reason}
          end
        else
          {:ok, updated_monitor}
        end
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{monitor: monitor}} -> {:ok, monitor}
        {:error, _failed_step, error, _changes} -> {:error, error}
      end
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Deletes a monitor and stops its worker.
  """
  @spec delete_monitor(Tenant.t(), Monitor.t()) :: {:ok, Monitor.t()} | {:error, any()}
  def delete_monitor(%Tenant{} = tenant, %Monitor{} = monitor) do
    if monitor.tenant_id == tenant.id do
      Multi.new()
      |> Multi.delete(:monitor, monitor)
      |> Multi.run(:engine_deregistration, fn _repo, _changes ->
        UptimeMonitor.Monitors.Engine.deregister(monitor)
        {:ok, :deregistered}
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{monitor: monitor}} -> {:ok, monitor}
        {:error, _failed_step, error, _changes} -> {:error, error}
      end
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Pauses a monitor.
  """
  @spec pause_monitor(Tenant.t(), Monitor.t()) :: {:ok, Monitor.t()} | {:error, any()}
  def pause_monitor(%Tenant{} = tenant, %Monitor{} = monitor) do
    update_monitor(tenant, monitor, %{"active" => false})
  end

  @doc """
  Resumes a monitor.
  """
  @spec resume_monitor(Tenant.t(), Monitor.t()) :: {:ok, Monitor.t()} | {:error, any()}
  def resume_monitor(%Tenant{} = tenant, %Monitor{} = monitor) do
    update_monitor(tenant, monitor, %{"active" => true})
  end

  # --- CheckResult logging ---

  @doc """
  Logs a check result.
  """
  @spec create_check_result(Monitor.t(), map()) :: {:ok, CheckResult.t()} | {:error, any()}
  def create_check_result(%Monitor{} = monitor, attrs) do
    %CheckResult{monitor_id: monitor.id}
    |> CheckResult.changeset(attrs)
    |> Repo.insert()
  end

  # --- Heartbeat CRUD & Operations ---

  @doc """
  Lists heartbeats scoped to a tenant.
  """
  @spec list_heartbeats(pos_integer()) :: [Heartbeat.t()]
  def list_heartbeats(tenant_id) do
    Heartbeat
    |> where([h], h.tenant_id == ^tenant_id)
    |> order_by([h], desc: h.inserted_at)
    |> Repo.all()
  end

  @doc """
  Creates a heartbeat passive configuration.
  """
  @spec create_heartbeat(Tenant.t(), map()) :: {:ok, Heartbeat.t()} | {:error, any()}
  def create_heartbeat(%Tenant{} = tenant, attrs) do
    %Heartbeat{tenant_id: tenant.id}
    |> Heartbeat.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Pings a heartbeat by token, updating the `last_pinged_at` timestamp.
  """
  @spec ping_heartbeat(String.t()) :: {:ok, Heartbeat.t()} | {:error, :not_found}
  def ping_heartbeat(token) when is_binary(token) do
    case Repo.get_by(Heartbeat, token: token) do
      nil ->
        {:error, :not_found}

      heartbeat ->
        heartbeat
        |> Ecto.Changeset.change(last_pinged_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update()
    end
  end
end
