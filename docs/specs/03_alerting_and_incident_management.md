# System Spec 03: Alerting, Incident Management & Debugging

This specification details state transition rules, notification dispatching, error logging logic, and the administrative workflow for incident post-mortems.

---

## 1. Objectives

*   Prevent alert fatigue by grouping sequential outages into a single logical "Incident".
*   Capture rich debugging payload records (failure logs) during outages without bloating database storage.
*   Design a modular notification pipeline that supports internal alerts, email, Slack, and custom webhooks.
*   Enable team collaboration by associating post-mortem reviews with resolved incidents.

---

## 2. State Machine & Incident Grouping

To manage outages, the platform tracks state transitions and groups failures into Incidents.

```
       ┌────────────────────────┐
       │                        │
       ▼                        │
 ┌──────────┐  Failed Check  ┌──┴───────┐
 │ Healthy  ├───────────────>│ Outage   │
 └────▲─────┘                └──┬───────┘
      │                         │
      │      Passed Check       │
      └─────────────────────────┘
```

### Transition States
*   **UP**: Target passes health assertions.
*   **DOWN**: Target fails health assertions.

### Outage Resolution Pipeline
1.  **Incident Creation**: When a monitor transitions from `UP` to `DOWN`, the system creates a new record in the `incidents` table (status: `:open`, type: `:outage`).
2.  **Notification Trigger**: An initial alert is dispatched immediately to all configured notification channels (e.g., mail, Slack).
3.  **Grouping**: While the monitor remains `DOWN`, subsequent check failures are logged in the database and linked to the active incident. **No additional notifications are sent to prevent spam**.
4.  **Resolution**: When a check succeeds, the monitor transitions to `UP`. The system updates the incident (status: `:resolved`, `resolved_at: DateTime.utc_now()`), calculates the total downtime, and dispatches a recovery alert.

---

## 3. Failure Log Capture (Debugging)

When an check fails, we store detailed diagnostics so developers can debug.

### Captured Attributes
*   **Timestamp**: Precise time of failure.
*   **Response Code**: HTTP code (e.g., `500`, `502`, `404`) or connection error atom (e.g., `:timeout`, `:nxdomain`).
*   **Response Headers**: Serialized JSON representation of returned headers.
*   **Response Body**: The first **2KB** of the response payload (excess data is truncated to save DB space and prevent memory bloat).
*   **Latency**: The duration of the request in milliseconds.

---

## 4. Notification & Alerting Pipeline

The alerting system uses an adapter pattern to easily scale integration types.

```elixir
defprotocol UptimeMonitor.Alerts.Adapter do
  @doc "Sends an alert notification for a specific event."
  @spec deliver(struct(), event :: map()) :: {:ok, term()} | {:error, term()}
  def deliver(adapter, event)
end
```

### Channels
1.  **Platform Notifications (Built-in)**: Writes to an `inbox_alerts` database table. Visible inside the user's dashboard notifications center.
2.  **Email**: Delivered asynchronously via `Swoosh` mail templates.
3.  **Slack/Discord Webhooks**: Sends a structured JSON payload to custom URLs defined in the tenant's integration settings.

---

## 5. Incident Post-Mortems

Once an incident is resolved, users with `Editor` or higher permissions can draft post-mortems.

### Post-Mortem Schema
*   `id` (Primary Key)
*   `incident_id` (Foreign Key referencing `incidents`, unique, null: false)
*   `title` (String, null: false)
*   `content` (Text/Markdown) - Explaining:
    *   **Root Cause**: What caused the failure.
    *   **Impact**: Who was affected, and for how long.
    *   **Action Items**: Preventive measures to avoid recurrence.
*   `created_by_id` (Foreign key referencing `users`, null: false)
