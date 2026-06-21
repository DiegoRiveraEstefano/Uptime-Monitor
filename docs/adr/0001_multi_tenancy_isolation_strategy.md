# Architectural Decision Record (ADR)

## Title: [ADR-0001] Multi-Tenancy Isolation Strategy

*   **Status**: `Accepted`
*   **Date**: 2026-06-20
*   **Author(s)**: Antigravity AI
*   **Deciders**: Diego (USER), Antigravity AI

---

## 1. Context and Problem Statement

`UptimeMonitor` is a multi-tenant platform. We need to isolate customer data (Monitors, Checks, Alertas, Incidents) so that no organization can view or edit resources belonging to another. We need to decide how to structure database tables and index models to guarantee isolation while maintaining performance and low operational complexity.

*   **Requirements**:
    *   Zero data leak risk between tenants.
    *   Must scale to support thousands of tenants.
    *   Fast query execution on tenant dashboards.
*   **Constraints**:
    *   PostgreSQL database.
    *   Limited database connection pools.
*   **Assumptions**:
    *   Most tenants will have moderate numbers of active monitors (10 to 500 checks).
    *   Cross-tenant global reporting (e.g. system-wide statistics) is useful for administrators.

---

## 2. Alternatives Considered

### Alternative A: Row-Level Scoping with `tenant_id`
All data is stored in shared database tables. Every tenant-specific table includes a `tenant_id` foreign key column. Every Ecto query must explicitly filter by this column (`where: tenant_id == ^current_tenant_id`).

*   **Pros**:
    *   Extremely simple database migrations and maintenance.
    *   Low memory footprint: one database connection pool, one set of schema definitions.
    *   Easy cross-tenant analytics for platform admins.
    *   Easy data migrations across tenants if needed.
*   **Cons**:
    *   High risk of data leaks if a developer forgets to scope a query (relying on code discipline or library wrappers).

### Alternative B: PostgreSQL Database Schema Separation (Multi-Schema)
A separate database schema is generated dynamically for each tenant (e.g., `tenant_acme`, `tenant_stripe`), separating tables physically.

*   **Pros**:
    *   Strong physical isolation: querying table names automatically scopes data to the current schema namespace.
    *   No risk of forgetting `tenant_id` clauses on queries.
*   **Cons**:
    *   High overhead: running migrations across thousands of schemas becomes extremely slow.
    *   Increased database resource consumption (indexes, schema cache, memory).
    *   Complex connection routing and multi-pool management.

---

## 3. Decision Outcome

**Chosen Option**: **Alternative A: Row-Level Scoping with `tenant_id`**

### Rationale:
*   **Operational Simplicity**: Elixir contexts can easily abstract query scoping, reducing the likelihood of missing scoping filters.
*   **Database Scaling**: Avoiding PostgreSQL multi-schema bloat allows us to scale to thousands of tenants using a single connection pool and lightweight, single-schema migrations.
*   **Performance**: Compound indexes (e.g., on `[:tenant_id, :id]`) ensure index-only scans, delivering sub-millisecond query responses inside tenant workspaces.

---

## 4. Consequences and Trade-offs

*   **Positive (Good)**:
    *   Fast migrations and minimal database resource bloat.
    *   Simple database backups and restores (standard Postgres operations).
*   **Negative (Bad/Risks)**:
    *   Requires strict code discipline. Developers must always scope queries.
*   **Neutral (Neutral)**:
    *   Ecto contexts must enforce the `tenant_id` or `current_tenant` parameters as mandatory for all fetch/manipulation functions.

---

## 5. References and Links

*   [System Spec 01: Multi-Tenancy & Access Control](file:///C:/Users/Diego/work/Uptime-Monitor/Uptime-Monitor/docs/specs/01_multi_tenancy_and_auth.md)
*   [Ecto Query Scoping Guidelines](file:///C:/Users/Diego/work/Uptime-Monitor/Uptime-Monitor/docs/models/template.md)
