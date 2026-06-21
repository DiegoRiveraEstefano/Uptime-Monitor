# Application Workflows & Flowcharts

This document defines the core business flows and execution paths for the `UptimeMonitor` platform using Mermaid diagrams.

---

## 1. User Registration & Tenant Creation Workflow

This workflow represents how new users sign up and initialize their isolated organization workspaces.

```mermaid
flowchart TD
    A[User fills Registration Form] --> B{Valid Email & Password?}
    B -- No --> C[Display Form Validation Errors]
    B -- Yes --> D[Execute Database Transaction Ecto.Multi]
    
    subgraph Ecto.Multi Transaction
        D --> E[Insert global User record]
        E --> F[Insert Tenant workspace]
        F --> G[Insert Membership mapping User to Tenant as owner]
    end
    
    G --> H{Transaction Successful?}
    H -- No --> I[Rollback & Return Database Errors]
    H -- Yes --> J[Establish User Session & Redirect to Dashboard]
    J --> K[Mount LiveView scoped to assigned tenant_id]
```

---

## 2. Active HTTP Monitor Lifecycle Loop

This sequence diagram details how the scheduler dynamically spawns check processes on startup and runs the recursive checking loop.

```mermaid
sequenceDiagram
    participant Engine as Monitors.Engine
    participant Sup as Monitors.DynamicSupervisor
    participant Worker as Monitors.Worker (GenServer)
    participant Task as Asynchronous Task
    participant HTTP as Target Endpoint
    participant Db as PostgreSQL

    Note over Engine: Application boot sequence
    Engine->>Db: Load all active Monitors
    loop For each Monitor
        Engine->>Sup: Start child process
        Sup->>Worker: Spawn GenServer worker process
        Note over Worker: Worker schedules first check
    end

    loop Every check_interval (e.g. 60 seconds)
        Worker->>Worker: self-message :tick
        Worker->>Task: Spawn Task process (HttpChecker.run/1)
        Note over Worker: Worker remains responsive to system updates
        Task->>HTTP: Fetch Target (headers, body content)
        HTTP-->>Task: Return Status, Body, Latency
        Task-->>Worker: Return result tuple
        Worker->>Db: Log check result to check_results table
        Note over Worker: Verify status transitions
    end
```

---

## 3. Passive Heartbeat Watchdog Workflow

This state diagram represents the passive "backward" monitoring watchdog which monitors incoming external heartbeat signals (e.g. from cronjobs).

```mermaid
stateDiagram-v2
    [*] --> Healthy : Create Heartbeat Monitor
    
    state Healthy {
        [*] --> WaitingForPing
        WaitingForPing --> PingReceived : External system curls /api/v1/heartbeat/:token
        PingReceived --> WaitingForPing : Update last_pinged_at & Reset grace timer
    }
    
    Healthy --> Outage : Grace timer expires (No ping received in expected interval + grace period)
    
    state Outage {
        [*] --> CreateIncident
        CreateIncident --> TriggerAlerts : Notify Owners/Admins
        TriggerAlerts --> WaitingForRecovery
        WaitingForRecovery --> RecoveryPingReceived : External system resumes sending heartbeats
    }
    
    Outage --> Healthy : RecoveryPingReceived (Resolve Incident & Send Recovery Alert)
```

---

## 4. Incident Lifecycle & Alert Dispatching Flow

This flowchart describes how outages are detected, aggregated, and reported without spamming team members.

```mermaid
flowchart TD
    A[Check execution completes with failure status] --> B{Active incident already open?}
    
    B -- Yes --> C[Append log detail to raw check_results]
    C --> D[Link log to existing Incident ID]
    D --> E[DO NOT send notifications - Prevent alert spam]
    
    B -- No --> F[Create new Incident with status open]
    F --> G[Dispatch Outage Event to Alerts.Dispatcher]
    G --> H[Query active Notification Channels for the Tenant]
    H --> I[Execute Task.async_stream to send alerts]
    I --> J[Adapters: Send Email, post Slack webhook, or call outgoing webhook]

    K[Check execution completes with success status] --> L{Active incident already open?}
    L -- No --> M[Do nothing - System is Healthy]
    L -- Yes --> N[Update Incident status to resolved]
    N --> O[Calculate downtime_seconds]
    O --> P[Dispatch Recovery Event to Alerts.Dispatcher]
    P --> Q[Send resolved alerts via active channels]
```

---

## 5. Metrics Rollup & Pruning Loop

This flowchart represents the automated database optimization process that summarizes logs and purges raw records.

```mermaid
flowchart TD
    A[Background Cron task RollupWorker fires] --> B{Time matches start of hour?}
    B -- Yes --> C[Aggregate check_results from previous hour]
    C --> D[Insert summaries into hourly_rollups]
    B -- No --> E[Skip hourly aggregation]
    
    D & E --> F{Time matches midnight?}
    F -- Yes --> G[Aggregate hourly_rollups from previous day]
    G --> H[Insert summaries into daily_rollups]
    H --> I[Run pruning: DELETE FROM check_results WHERE age > 14 days]
    I --> J[Run pruning: DELETE FROM hourly_rollups WHERE age > 90 days]
    F -- No --> K[Skip daily aggregation]
    
    K & J --> L[Schedule next RollupWorker tick in 1 hour]
```
