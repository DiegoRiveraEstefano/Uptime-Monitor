# Monitors Domain Module Details

This document details the specifications, schemas, OTP worker GenServers, and execution handlers for the `UptimeMonitor.Monitors` domain.

---

## 1. Context: `UptimeMonitor.Monitors`
Main context for managing the targets that need checking. All database creations/updates must trigger appropriate engine registration calls.

### Public API Specifications
*   `list_monitors(tenant_id)`:
    *   **Output**: `[%Monitor{}]`
*   `create_monitor(tenant, attrs)`:
    *   **Behavior**: Saves monitor inside an Ecto transaction and, if active, requests the `Engine` to spin up its worker process.
    *   **Output**: `{:ok, %Monitor{}}` | `{:error, term()}`
*   `pause_monitor(tenant, monitor)`:
    *   **Behavior**: Updates database status and calls `Engine.deregister(monitor)` to stop its active worker process.
    *   **Output**: `{:ok, %Monitor{}}` | `{:error, term()}`

---

## 2. Schema: `UptimeMonitor.Monitors.Monitor`
Stores check configurations.

### Fields and Schema
*   `name` (`:string`, null: false)
*   `url` (`:string`, null: false)
*   `interval_seconds` (`:integer`, default: 60) - Minimum: 30.
*   `active` (`:boolean`, default: true)
*   `encrypted_headers` (`:map`) - Encrypted JSON object holding auth keys.
*   `tenant_id` (`belongs_to` `Tenant`)

---

## 3. Schema: `UptimeMonitor.Monitors.Heartbeat`
Configuration for backward/push checks.

### Fields and Schema
*   `name` (`:string`, null: false)
*   `token` (`:string`, null: false, unique) - Random token.
*   `expected_interval_seconds` (`:integer`, default: 86400)
*   `grace_period_seconds` (`:integer`, default: 900)
*   `last_pinged_at` (`:utc_datetime`)
*   `tenant_id` (`belongs_to` `Tenant`)

---

## 4. Schema: `UptimeMonitor.Monitors.CheckResult`
Log details for every check.

### Fields and Schema
*   `monitor_id` (`belongs_to` `Monitor`, null: false)
*   `status` (`:string`, null: false) - `"up"` or `"down"`.
*   `latency_ms` (`:integer`, null: false)
*   `response_code` (`:integer` | `:string`) - HTTP code or error atom (e.g. `:timeout`).
*   `debug_response_body` (`:string`) - Truncated to 2KB on failure; nil on success.

---

## 5. OTP Engine Modules

### `UptimeMonitor.Monitors.Engine`
A central registry process.
*   **Behavior**:
    *   At startup, fetches active monitors from DB and registers them with `DynamicSupervisor`.
    *   Exposes `register(monitor)` and `deregister(monitor)` client calls.

### `UptimeMonitor.Monitors.DynamicSupervisor`
Provides supervision isolation.
*   **Behavior**: Dynamic supervisor (`one_for_one` strategy) supervising `UptimeMonitor.Monitors.Worker` processes.

### `UptimeMonitor.Monitors.Worker`
A long-running scheduler process per active monitor.
*   **Behavior**:
    *   Uses `Process.send_after/3` to schedule checks at interval intervals.
    *   On tick, spawns a `Task` to run `HttpChecker.run/1` asynchronously.
    *   Handles task returns, logs `CheckResult` to database, and notifies `UptimeMonitor.Incidents` if a transition occurs.

### `UptimeMonitor.Monitors.HttpChecker`
Pure function executing request.
*   **Behavior**:
    *   Decrypts custom headers from `encrypted_headers`.
    *   Dispatches an HTTP check request via `Req`.
    *   Evaluates status codes and body matches. Returns `{:ok, latency, code}` or `{:error, reason}`.
