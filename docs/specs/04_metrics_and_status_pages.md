# System Spec 04: Metrics, Uptime & Public Status Pages

This specification defines the metrics calculation model, database rollup strategy, real-time dashboard layout requirements, and configurable public status pages.

---

## 1. Objectives

*   Compute high-accuracy uptime percentages over arbitrary sliding windows (30/60/90 days).
*   Optimize database lookups using precalculated rollup metrics to ensure dashboard queries are fast and lightweight.
*   Expose highly customizable public status pages for transparency with external users.
*   Allow tenants to toggle visibility constraints on public status pages.

---

## 2. Uptime Calculation and Rollup Strategy

### The Formula
Uptime is calculated based on total downtime duration recorded within a given time frame:

$$\text{Uptime \%} = \left( 1 - \frac{\text{Total Downtime Seconds}}{\text{Total Monitored Seconds}} \right) \times 100$$

### Database Rollup Pattern
Querying raw check history records (e.g., checks run every 30s) to compile 90-day charts scales poorly and strains system resources. Instead, we compile hourly and daily rollups.

```
                  ┌──────────────────────┐
                  │  Raw Check Results   │ (Retained for 14 days)
                  └──────────┬───────────┘
                             │ Compiled Hourly
                             ▼
                  ┌──────────────────────┐
                  │ Hourly Monitor Stats │ (Retained for 90 days)
                  └──────────┬───────────┘
                             │ Compiled Daily
                             ▼
                  ┌──────────────────────┐
                  │ Daily Monitor Stats  │ (Retained Indefinitely)
                  └──────────────────────┘
```

#### Hourly Monitor Stats Schema
*   `monitor_id` (Foreign Key referencing `monitors`)
*   `hour` (DateTime, truncated to start of hour)
*   `total_checks` (Integer)
*   `failed_checks` (Integer)
*   `total_latency_ms` (Integer) - Cumulative latency, used to compute average: `total_latency_ms / total_checks`.

---

## 3. Dashboard Metrics Requirements

The main user dashboard provides tenant-wide summaries in real time:

*   **Current Service Status**: Summary indicators of healthy vs degraded vs offline monitors.
*   **Average Response Latency**: Aggregated average latency (in ms) across the last 24 hours.
*   **Active Incidents**: Direct interface list to review, update, or resolve open outages.
*   **SLA Threshold Check**: Displays actual uptime percentage vs the tenant's targeted SLA (e.g. `99.9%`).

---

## 4. Public Status Pages

Tenants can showcase their reliability to customers through standalone public status pages.

### Settings and Configuration
*   **Route**: `/status/:slug` (e.g., `https://status.uptime.com/status/acme-corp`).
*   **Visibility Toggle**: `is_public` (Boolean). If `false`, accessing the URL returns a `404` or prompts for password authorization.
*   **Page Customization**:
    *   **Custom Title**: Defaults to "ACME Corp System Status".
    *   **Monitors Selection**: Configuration list selecting which monitors to display publicly (some monitors may remain internal-only).
    *   **Support/Help URL**: Link redirection for support tickets during outages.

### UI Sections on Status Page
1.  **Global Status Indicator**: Single color banner (Green: "All Systems Operational", Orange: "Degraded Performance", Red: "Major Outage").
2.  **Uptime History Grid**: 90-day operational grid bar indicating daily uptime status (similar to the GitHub status grid).
3.  **Active Incidents Log**: Shows details of open incidents, along with update timestamps.
4.  **Historical Incidents**: Grouped listings of past incidents resolved within the last 7 to 15 days.
