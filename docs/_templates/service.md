# Elixir Services / Contexts Design Template

In this project, Contexts (also referred to as Services) act as the public entry points for our business logic. They decouple our web interfaces (Phoenix LiveViews, Controllers) from our data storage layer (Ecto schemas).

---

## 1. Core Principles

*   **Boundary Enforcement**: Web controllers, LiveViews, and API channels must only talk to contexts. They should never invoke `Repo` directly.
*   **Transaction Boundaries**: Multi-step business procedures must use `Ecto.Multi` or `Repo.transaction/2` inside the context to ensure atomicity.
*   **Tenant Scoping**: All service calls must be tenant-aware. Always require a `tenant_id` or `tenant` struct to scope queries, preventing cross-tenant data leaks.
*   **Decoupled Side Effects**: Actions like sending emails, scheduling checks, or broadcasting LiveView messages should occur *after* database transactions succeed to avoid holding database connections open.

---

## 2. Template Context Module

Use this structural outline when building contexts. This example implements a service for managing uptime monitors:

```elixir
defmodule UptimeMonitor.Monitors do
  @moduledoc """
  The Monitors context. Handles creating, updating, checking, and deleting uptime targets.
  """

  import Ecto.Query, warn: false
  
  alias Ecto.Multi
  alias UptimeMonitor.Repo
  alias UptimeMonitor.Monitors.Monitor
  alias UptimeMonitor.Accounts.Tenant

  @doc """
  Returns the list of monitors for a specific tenant.
  """
  @spec list_monitors(Tenant.t() | integer()) :: [Monitor.t()]
  def list_monitors(%Tenant{id: tenant_id}), do: list_monitors(tenant_id)
  def list_monitors(tenant_id) do
    Monitor
    |> where([m], m.tenant_id == ^tenant_id)
    |> order_by([m], desc: m.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single monitor scoped to a tenant.
  """
  @spec get_monitor(Tenant.t() | integer(), integer()) :: {:ok, Monitor.t()} | {:error, :not_found}
  def get_monitor(tenant_id, id) do
    case Repo.one(from m in Monitor, where: m.id == ^id and m.tenant_id == ^tenant_id) do
      nil -> {:error, :not_found}
      monitor -> {:ok, monitor}
    end
  end

  @doc """
  Creates a monitor and registers it with the dynamic monitoring engine in a database transaction.
  """
  @spec create_monitor(Tenant.t(), map()) :: {:ok, %{monitor: Monitor.t()}} | {:error, term()}
  def create_monitor(%Tenant{} = tenant, attrs) do
    Multi.new()
    # 1. Insert database record (scoped to tenant)
    |> Multi.insert(:monitor, Monitor.changeset(%Monitor{tenant_id: tenant.id}, attrs))
    # 2. Run post-insert actions (e.g. start dynamic GenServer check task)
    |> Multi.run(:engine_registration, fn _repo, %{monitor: monitor} ->
      case UptimeMonitor.Monitors.Engine.register(monitor) do
        :ok -> {:ok, :registered}
        {:error, reason} -> {:error, reason}
      end
    end)
    |> Repo.transaction()
    |> handle_transaction_result()
  end

  @doc """
  Pauses a monitor and updates its engine registration.
  """
  @spec pause_monitor(Tenant.t(), Monitor.t()) :: {:ok, Monitor.t()} | {:error, term()}
  def pause_monitor(%Tenant{} = tenant, %Monitor{} = monitor) do
    # Ensure monitor belongs to tenant before acting
    if monitor.tenant_id == tenant.id do
      Multi.new()
      |> Multi.update(:monitor, Monitor.pause_changeset(monitor))
      |> Multi.run(:engine_deregistration, fn _repo, %{monitor: monitor} ->
        UptimeMonitor.Monitors.Engine.deregister(monitor)
        {:ok, :deregistered}
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{monitor: monitor}} -> {:ok, monitor}
        {:error, _failed_op, reason, _changes} -> {:error, reason}
      end
    else
      {:error, :unauthorized}
    end
  end

  # Helper to parse standard Ecto.Multi transactions
  defp handle_transaction_result({:ok, changes}), do: {:ok, changes}
  defp handle_transaction_result({:error, _failed_step, error_value, _changes_so_far}) do
    {:error, error_value}
  end
end
```

---

## 3. Error Handling Best Practices
*   **Result Tuples**: Always prefer returning standard result tuples (`{:ok, data}` or `{:error, reason}`). Avoid raising exceptions for expected business errors (e.g., validations, entity not found).
*   **Pipelining with `with`**: Avoid nested case statements. Use `with` blocks to pipeline sequential validation steps:
    ```elixir
    def check_and_alert(tenant_id, monitor_id) do
      with {:ok, monitor} <- get_monitor(tenant_id, monitor_id),
           {:ok, check_result} <- run_check(monitor),
           :ok <- process_alerts(monitor, check_result) do
        {:ok, check_result}
      else
        {:error, :not_found} -> {:error, "Monitor not found"}
        {:error, reason} -> {:error, reason}
      end
    end
    ```
