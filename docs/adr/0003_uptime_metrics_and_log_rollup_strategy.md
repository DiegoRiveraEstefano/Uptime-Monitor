# Architectural Decision Record (ADR)

## Title: [ADR-0003] Uptime Metrics and Log Rollup Strategy

*   **Status**: `Accepted`
*   **Date**: 2026-06-20
*   **Author(s)**: Antigravity AI
*   **Deciders**: Diego (USER), Antigravity AI

---

## 1. Context and Problem Statement

To display historical uptime percentages and response latency charts (e.g. 90-day status grids, average latencies) on user dashboards and public status pages, we need to process check results. A single monitor running checks every 30 seconds generates ~86,400 logs per month. With thousands of monitors, the raw check results table will grow by millions of records weekly. Querying this table dynamically for dashboards will quickly lead to database exhaustion and slow page load times.

*   **Requirements**:
    *   Dashboard metric loads must be fast (under 200ms).
    *   Uptime SLA calculations must handle historical windows up to 1 year.
    *   Prevent PostgreSQL database storage from bloating.
*   **Constraints**:
    *   Limited database storage and memory.
*   **Assumptions**:
    *   Users do not need millisecond-level resolution for checks older than 14 days; aggregate data (hourly/daily averages) is sufficient.

---

## 2. Alternatives Considered

### Alternative A: Raw Query Execution on Demand
Calculate all metrics (uptime, latency averages) dynamically by running Ecto queries (e.g. `avg/sum`) directly on the raw `check_results` table every time a user loads the dashboard.

*   **Pros**:
    *   Real-time and 100% accurate data.
    *   No complex background sync jobs or rollup schemas to maintain.
*   **Cons**:
    *   Non-scalable: query performance degrades exponentially as check history grows.
    *   High memory and CPU load on PostgreSQL.

### Alternative B: Aggregate Rollup Tables with Data Retention Policy
Store raw checks in a transient table (`check_results`). Periodically (or dynamically) aggregate these results into hourly and daily summary tables (`hourly_monitor_stats`, `daily_monitor_stats`). Apply a retention policy that deletes raw checks older than 14 days.

*   **Pros**:
    *   High dashboard query performance: summary tables are 100x to 1000x smaller than the raw log tables.
    *   Controlled database growth: database size remains stable over time due to the retention pruning policy.
*   **Cons**:
    *   Loss of raw resolution for older checks (cannot inspect the exact HTTP headers of a successful check from 3 months ago).
    *   Requires managing aggregation jobs and pruning processes (e.g. cron-like periodic tasks).

---

## 3. Decision Outcome

**Chosen Option**: **Alternative B: Aggregate Rollup Tables with Data Retention Policy**

### Rationale:
*   **Performance**: Querying precalculated hourly/daily summaries enables sub-50ms dashboard page loads, ensuring a high-quality user experience.
*   **Cost & Storage Efficiency**: Deleting raw logs older than 14 days prevents the database from expanding indefinitely, keeping storage costs predictable.
*   **Analytics Adequacy**: Hourly/daily rollups preserve critical metrics (uptime ratios, average latency, total failures) indefinitely, satisfying SLA auditing requirements.

---

## 4. Consequences and Trade-offs

*   **Positive (Good)**:
    *   Consistent dashboard latency.
    *   Predictable database storage growth.
*   **Negative (Bad/Risks)**:
    *   Raw check details (headers, payload) are only available for 14 days. This is acceptable since debugging is typically done on recent outages.
*   **Neutral (Neutral)**:
    *   Must implement a cron/cleanup worker (e.g., using a background scheduler or simple Ecto queries) to handle aggregation and delete expired raw records daily.

---

## 5. References and Links

*   [System Spec 04: Metrics, Uptime & Public Status Pages](file:///C:/Users/Diego/work/Uptime-Monitor/Uptime-Monitor/docs/specs/04_metrics_and_status_pages.md)
