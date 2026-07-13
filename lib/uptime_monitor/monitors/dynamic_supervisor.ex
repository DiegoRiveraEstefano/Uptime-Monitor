defmodule UptimeMonitor.Monitors.DynamicSupervisor do
  @moduledoc """
  Supervisor that manages dynamic spawning and lifecycle of Monitor Workers.
  """
  use DynamicSupervisor

  @spec start_link(any()) :: Supervisor.on_start()
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Spawns a worker GenServer for a monitor target.
  """
  @spec start_worker(UptimeMonitor.Monitors.Monitor.t()) :: DynamicSupervisor.on_start_child()
  def start_worker(%UptimeMonitor.Monitors.Monitor{} = monitor) do
    spec = {UptimeMonitor.Monitors.Worker, monitor}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @doc """
  Terminates an active worker GenServer for a monitor.
  """
  @spec stop_worker(pos_integer()) :: :ok | {:error, :not_found}
  def stop_worker(monitor_id) do
    case GenServer.whereis({:global, {:monitor_worker, monitor_id}}) do
      nil ->
        :ok

      pid ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end
end
