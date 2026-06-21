# Metrics & StatusPages Domain Module Details

This document details the specifications, database rollup schemas, SLA metric calculators, background aggregator workers, and public status page modules for the `UptimeMonitor.Metrics` and `UptimeMonitor.StatusPages` domains.

---

## 1. Context: `UptimeMonitor.Metrics`
Consolidates performance data and calculates SLA percentages.

### Public API Specifications
*   `get_uptime_percentage(monitor, days)`:
    *   **Input**: A `%Monitor{}` and integer days (e.g., 30, 90).
    *   **Behavior**: Queries `DailyRollup` records to compute aggregate uptime.
    *   **Output**: `{:ok, float()}` | `{:error, term()}`
*   `get_latency_history(monitor, days)`:
    *   **Output**: `[{Date.t(), avg_latency_ms :: integer()}]`

---

## 2. Schemas: Rollup Tables
Summarizes millions of raw check logs into aggregate rows.

### `UptimeMonitor.Metrics.HourlyRollup`
*   `monitor_id` (`belongs_to` `Monitor`, null: false)
*   `hour` (`:utc_datetime`, null: false) - Truncated start of hour.
*   `total_checks` (`:integer`, null: false)
*   `failed_checks` (`:integer`, null: false)
*   `total_latency_ms` (`:integer`, null: false)

### `UptimeMonitor.Metrics.DailyRollup`
*   `monitor_id` (`belongs_to` `Monitor`, null: false)
*   `date` (`:date`, null: false)
*   `total_checks` (`:integer`, null: false)
*   `failed_checks` (`:integer`, null: false)
*   `total_latency_ms` (`:integer`, null: false)

---

## 3. Support Modules

### `UptimeMonitor.Metrics.Calculator`
A functional module containing mathematical SLA formulas.
*   **Behavior**:
    *   Calculates percentage ratio: `(1 - (failed_checks / total_checks)) * 100`.
    *   Estimates average latency: `total_latency_ms / total_checks`.

### `UptimeMonitor.Metrics.RollupWorker`
A background cron worker process.
*   **Behavior**:
    *   Ticked periodically (every hour) using `Process.send_after/3`.
    *   Queries raw `CheckResult` logs from the previous hour, aggregates them, and writes results to `HourlyRollup`.
    *   Queries `HourlyRollup` at midnight, aggregates them, and writes results to `DailyRollup`.
    *   Applies the data retention policy: runs `DELETE FROM check_results WHERE inserted_at < datetime_now() - 14_days`.

---

## 4. Context & Schema: `UptimeMonitor.StatusPages`
Handles public display of system status grids.

### Context Public API
*   `get_status_page_by_slug(slug)`:
    *   **Behavior**: Retrieves page settings and preloaded active monitors. Returns public info if `is_public` is true.
    *   **Output**: `{:ok, %StatusPage{}}` | `{:error, :not_found} | {:error, :unauthorized}`

### Schema: `UptimeMonitor.StatusPages.StatusPage`
Public status page configuration.
*   `title` (`:string`, null: false)
*   `slug` (`:string`, null: false, unique) - E.g. `"acme"`.
*   `is_public` (`:boolean`, default: true)
*   `visible_monitor_ids` (`:array`, `:integer`) - Selection of monitors shown on the status page.
*   `tenant_id` (`belongs_to` `Tenant`)
