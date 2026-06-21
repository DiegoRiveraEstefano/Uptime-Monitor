defmodule UptimeMonitor.Monitors.Engine do
  @moduledoc """
  Core engine scheduler coordinator. Boots existing monitors and manages registration events.
  """
  use GenServer

  alias UptimeMonitor.Monitors.DynamicSupervisor

  # --- Client API ---

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Registers and starts a monitor worker.
  """
  @spec register(UptimeMonitor.Monitors.Monitor.t()) :: :ok | {:error, any()}
  def register(%UptimeMonitor.Monitors.Monitor{} = monitor) do
    GenServer.call(__MODULE__, {:register, monitor})
  end

  @doc """
  Deregisters and stops a monitor worker.
  """
  @spec deregister(UptimeMonitor.Monitors.Monitor.t()) :: :ok | {:error, any()}
  def deregister(%UptimeMonitor.Monitors.Monitor{} = monitor) do
    GenServer.call(__MODULE__, {:deregister, monitor})
  end

  # --- Server Callbacks ---

  @impl GenServer
  def init(init_arg) do
    # Perform database operations asynchronously after boot to avoid blocking startup
    send(self(), :post_init)
    {:ok, init_arg}
  end

  @impl GenServer
  def handle_info(:post_init, state) do
    # Load active monitors and start their dynamic workers
    # TODO: Consider batching or rate-limiting if there are many monitors to avoid overwhelming the system at startup
    monitors = UptimeMonitor.Monitors.list_active_monitors()

    Enum.each(monitors, fn monitor ->
      DynamicSupervisor.start_worker(monitor)
    end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:register, monitor}, _from, state) do
    case DynamicSupervisor.start_worker(monitor) do
      {:ok, _pid} -> {:reply, :ok, state}
      {:ok, _pid, _info} -> {:reply, :ok, state}
      {:error, {:already_started, _pid}} -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:deregister, monitor}, _from, state) do
    res = DynamicSupervisor.stop_worker(monitor.id)
    {:reply, res, state}
  end
end
