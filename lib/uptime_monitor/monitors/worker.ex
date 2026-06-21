defmodule UptimeMonitor.Monitors.Worker do
  @moduledoc """
  A GenServer process that schedules and executes active checks for a specific monitor.
  """
  use GenServer, restart: :transient

  alias UptimeMonitor.Monitors.{Monitor, HttpChecker}

  @type state :: %{
    monitor: Monitor.t(),
    current_task: {reference(), pid()} | nil,
    last_status: String.t()
  }

  # --- Client API ---

  @doc """
  Starts a worker process for a specific monitor.
  """
  @spec start_link(Monitor.t()) :: GenServer.on_start()
  def start_link(%Monitor{} = monitor) do
    # Name the process by monitor id to prevent duplicates
    GenServer.start_link(__MODULE__, monitor, name: via_tuple(monitor.id))
  end

  # --- Server Callbacks ---

  @impl GenServer
  def init(%Monitor{} = monitor) do
    # Schedule check to execute immediately
    send(self(), :tick)
    {:ok, %{monitor: monitor, current_task: nil, last_status: "up"}}
  end

  @impl GenServer
  def handle_info(:tick, %{current_task: nil} = state) do
    # Spawn non-blocking task to check target
    task = Task.async(fn -> HttpChecker.run(state.monitor) end)
    {:noreply, %{state | current_task: {task.ref, task.pid}}}
  end

  # If a tick occurs but the previous task is still running (overlap/timeout)
  def handle_info(:tick, state) do
    # Log warning, skip this tick, and reschedule
    schedule_next_tick(state.monitor.interval_seconds)
    {:noreply, state}
  end

  # Handle Task Success Return
  @impl GenServer
  def handle_info({ref, check_result}, %{current_task: {ref, _pid}} = state) do
    # 1. Demonitor task (Task.async automatically demonitors, so we just wait for DOWN)
    Process.demonitor(ref, [:flush])
    
    # 2. Process check results
    {status, latency_ms, code, body} =
      case check_result do
        {:ok, latency, status_code} ->
          {"up", latency, status_code, nil}
        {:error, latency, reason, body_snippet} ->
          {"down", latency, nil, "#{reason}\n#{body_snippet}"}
      end

    # 3. Log results to database
    {:ok, _result} = UptimeMonitor.Monitors.create_check_result(state.monitor, %{
      status: status,
      latency_ms: latency_ms,
      response_code: code,
      debug_response_body: body
    })

    # 4. Handle state transition and notify Incidents domain
    new_status = process_status_transition(state.monitor, state.last_status, status, body)

    # 5. Schedule next check
    schedule_next_tick(state.monitor.interval_seconds)

    {:noreply, %{state | current_task: nil, last_status: new_status}}
  end

  # Handle Task Failures / Crashes
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{current_task: {ref, _task_pid}} = state) do
    # Log crash result to database
    {:ok, _result} = UptimeMonitor.Monitors.create_check_result(state.monitor, %{
      status: "down",
      latency_ms: 0,
      response_code: 500,
      debug_response_body: "Process crash: #{inspect(reason)}"
    })

    # Transition to down and notify incidents
    new_status = process_status_transition(state.monitor, state.last_status, "down", "Process crashed: #{inspect(reason)}")

    # Schedule next check
    schedule_next_tick(state.monitor.interval_seconds)

    {:noreply, %{state | current_task: nil, last_status: new_status}}
  end

  # Catch-all for stray messages
  def handle_info(_, state), do: {:noreply, state}

  # --- Helper functions ---

  defp via_tuple(monitor_id) do
    # Using registry or standard local naming. For simplicity, local atomic naming:
    # (Since Registry requires config names, Registry is preferred for dynamic OTP apps.
    # Registry is already imported by Phoenix default, or we can use Registry on application startup).
    # Let's register process globally using custom name:
    {:global, {:monitor_worker, monitor_id}}
  end

  defp schedule_next_tick(seconds) do
    Process.send_after(self(), :tick, :timer.seconds(seconds))
  end

  defp process_status_transition(monitor, last_status, current_status, reason) do
    case {last_status, current_status} do
      {"up", "down"} ->
        # Transition UP -> DOWN: Trigger Incident
        # Call Incidents context dynamically (will implement in next step)
        apply(UptimeMonitor.Incidents, :report_failure, [monitor, reason])
        "down"

      {"down", "up"} ->
        # Transition DOWN -> UP: Recover Incident
        apply(UptimeMonitor.Incidents, :report_recovery, [monitor])
        "up"

      _ ->
        # No transition (up->up or down->down).
        # If it remains down, we append checking updates internally
        if current_status == "down" do
          apply(UptimeMonitor.Incidents, :report_failure, [monitor, reason])
        end
        current_status
    end
  end
end
