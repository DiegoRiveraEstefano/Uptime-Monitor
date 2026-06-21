# Incidents & Alerts Domain Module Details

This document details the specifications, schemas, protocols, and notification adapters for the `UptimeMonitor.Incidents` and `UptimeMonitor.Alerts` domains.

---

## 1. Context: `UptimeMonitor.Incidents`
Orchestrates the lifecycle of outages and monitors transitions.

### Public API Specifications
*   `report_failure(monitor, reason_payload)`:
    *   **Behavior**: Called by a `Worker` when a check fails. Checks if there is an active `:open` incident for the monitor. If none, inserts a new `Incident`, and fires alerts. If one exists, appends the failure details to the incident log.
    *   **Output**: `{:ok, %Incident{}}`
*   `report_recovery(monitor)`:
    *   **Behavior**: Called by a `Worker` when a check passes. Finds the active `:open` incident, updates it to `:resolved`, calculates total downtime duration, and dispatches recovery alerts.
    *   **Output**: `{:ok, %Incident{}}` | `{:error, :no_active_incident}`

---

## 2. Schema: `UptimeMonitor.Incidents.Incident`
Represents an active or resolved system outage.

### Fields and Schema
*   `status` (`:string`, default: `"open"`) - `"open"`, `"resolved"`.
*   `opened_at` (`:utc_datetime`, null: false)
*   `resolved_at` (`:utc_datetime`, null: true)
*   `downtime_seconds` (`:integer`, null: true)
*   `monitor_id` (`belongs_to` `Monitor`)
*   `tenant_id` (`belongs_to` `Tenant`)
*   `post_mortem` (`has_one` `PostMortem`)

---

## 3. Schema: `UptimeMonitor.Incidents.PostMortem`
A markdown post-outage analysis.

### Fields and Schema
*   `title` (`:string`, null: false)
*   `content` (`:string`, null: false) - Markdown content mapping root cause and mitigation steps.
*   `incident_id` (`belongs_to` `Incident`)
*   `created_by_id` (`belongs_to` `User`)

---

## 4. Context & Schema: `UptimeMonitor.Alerts`
Manages notification targets, routing configurations, and platform message dispatching.

### Context Public API
*   `dispatch_incident_alert(incident, event_type)`:
    *   **Behavior**: Spawns an async Task requesting `Dispatcher` to route the incident event to all channels.
*   `list_notification_channels(tenant_id)`:
    *   **Output**: `[%NotificationChannel{}]`

### Schemas
*   `UptimeMonitor.Alerts.NotificationChannel`:
    *   **Fields**: `type` (`:string`), `config` (`:map` - stores keys, webhooks encrypted), `active` (`:boolean`), `tenant_id` (`belongs_to` `Tenant`).
*   `UptimeMonitor.Alerts.PlatformNotification`:
    *   **Fields**: `title` (`:string`), `message` (`:string`), `read` (`:boolean`), `tenant_id` (`belongs_to` `Tenant`).

---

## 5. Alert Dispatching Architecture

### `UptimeMonitor.Alerts.Dispatcher`
Acts as the router.
*   **Behavior**: Fetches active `NotificationChannel` structures for the incident's tenant. Maps channels to their corresponding `Adapter` module, and executes alerts asynchronously using `Task.async_stream/3`.

### `UptimeMonitor.Alerts.Adapter` (Protocol)
An Elixir protocol mapping alerts delivery:
```elixir
defprotocol UptimeMonitor.Alerts.Adapter do
  @spec deliver(struct(), event :: map()) :: {:ok, term()} | {:error, term()}
  def deliver(adapter_config, event)
end
```

### Adapters
*   `UptimeMonitor.Alerts.Adapters.Email`: Swoosh mailer implementation. Sends customized templates using SMTP or API integrations.
*   `UptimeMonitor.Alerts.Adapters.Webhook`: JSON dispatcher that sends a POST body payload containing `event_type` (`incident_opened`, `incident_resolved`), latency, URL, and error detail logs.
