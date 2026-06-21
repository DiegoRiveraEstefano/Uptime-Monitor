# Domain Module Architecture

This document defines the list of Elixir modules required to satisfy the system specifications and Architectural Decision Records (ADRs). Modules are grouped by **Phoenix Business Contexts** (Domains).

---

## 1. Domain Map Overview

```
UptimeMonitor (Root Application)
 ├── Accounts (Domain 1: Identity & Isolation)
 ├── Monitors (Domain 2: Check Scheduling & Engine)
 ├── Incidents & Alerts (Domain 3: Outages & Notifications)
 └── Metrics & StatusPages (Domain 4: SLA Calculations & Reporting)
```

---

## 2. Context: Accounts (`UptimeMonitor.Accounts`)
This domain handles user registration, session management, organization isolation (tenants), and Role-Based Access Control (RBAC).

| Module Name | Type | Responsibility |
| :--- | :--- | :--- |
| `UptimeMonitor.Accounts` | Context | Public entry point for creating users, tenants, memberships, and authenticating sessions. |
| `UptimeMonitor.Accounts.User` | Schema | Database mapping for users (email, password hashes). |
| `UptimeMonitor.Accounts.Tenant` | Schema | Database mapping for organizations (slug, name, billing configurations). |
| `UptimeMonitor.Accounts.Membership` | Schema | Join schema mapping users to tenants, holding the role enum (`owner`, `admin`, `editor`, `viewer`). |
| `UptimeMonitorWeb.Plugs.RequireTenant` | Plug | Web middleware that resolves the current tenant context from the session or path and assigns it to the connection. |
| `UptimeMonitorWeb.Plugs.RequireRole` | Plug | Web middleware that enforces membership role permissions (e.g. requires `editor` role to access edit routes). |

---

## 3. Context: Monitors (`UptimeMonitor.Monitors`)
This domain is the monitoring scheduling core. It holds check targets, registers them with the OTP engine, and manages check executions.

| Module Name | Type | Responsibility |
| :--- | :--- | :--- |
| `UptimeMonitor.Monitors` | Context | Public entry point to manage (CRUD, pause, resume) active monitors and heartbeat configurations. |
| `UptimeMonitor.Monitors.Monitor` | Schema | Database schema for active targets (URL, protocol details, check intervals, custom encrypted headers). |
| `UptimeMonitor.Monitors.Heartbeat` | Schema | Database schema for incoming push checks (grace periods, expected intervals, heartbeat tokens). |
| `UptimeMonitor.Monitors.CheckResult` | Schema | Database schema for raw logs (timestamp, response latency, code, truncated error response payload). |
| `UptimeMonitor.Monitors.Engine` | OTP GenServer | Reads active database monitor records at system boot, monitors workers, and handles dynamic state transitions (starting/stopping workers). |
| `UptimeMonitor.Monitors.DynamicSupervisor` | OTP Supervisor | Oversees individual check workers, ensuring failure boundaries are isolated. |
| `UptimeMonitor.Monitors.Worker` | OTP GenServer | A process spawned for each active monitor that handles tick-scheduling and schedules tasks. |
| `UptimeMonitor.Monitors.HttpChecker` | Module | Pure-logic execution helper that makes HTTP requests via `Req` and tests health assertions (status codes, body matchers). |

---

## 4. Contexts: Incidents & Alerts (`UptimeMonitor.Incidents` & `UptimeMonitor.Alerts`)
Handles incident lifecycles (outage grouping), alert deliveries across various adapters, and incident post-mortem documentation.

| Module Name | Type | Responsibility |
| :--- | :--- | :--- |
| `UptimeMonitor.Incidents` | Context | Entry point to manage outages, log failure intervals, and link post-mortems. |
| `UptimeMonitor.Incidents.Incident` | Schema | Database mapping representing an active or resolved outage window. Groups subsequent check failures. |
| `UptimeMonitor.Incidents.PostMortem` | Schema | Markdown analytical reviews associated with a resolved incident. |
| `UptimeMonitor.Alerts` | Context | Public entry point to configure notification integrations and trigger alert dispatches. |
| `UptimeMonitor.Alerts.NotificationChannel` | Schema | Configuration for external channels (Slack webhook URLs, pagerduty integration keys, etc.). |
| `UptimeMonitor.Alerts.PlatformNotification` | Schema | Database storage for built-in dashboard alerts. |
| `UptimeMonitor.Alerts.Dispatcher` | GenServer/Task | Routes an active incident event to all associated notification adapters. |
| `UptimeMonitor.Alerts.Adapter` | Protocol | Defines standard interfaces for alert adapter modules. |
| `UptimeMonitor.Alerts.Adapters.Email` | Adapter | Swoosh implementation for email alerts. |
| `UptimeMonitor.Alerts.Adapters.Webhook` | Adapter | JSON webhook dispatcher. |

---

## 5. Contexts: Metrics & StatusPages (`UptimeMonitor.Metrics` & `UptimeMonitor.StatusPages`)
Focuses on precalculating historical aggregates, evaluating SLA criteria, and managing public status pages.

| Module Name | Type | Responsibility |
| :--- | :--- | :--- |
| `UptimeMonitor.Metrics` | Context | API to query aggregated averages, sliding-window SLAs, and retrieve summary statistics. |
| `UptimeMonitor.Metrics.HourlyRollup` | Schema | Precalculated hourly log counts, fail counts, and latencies. |
| `UptimeMonitor.Metrics.DailyRollup` | Schema | Precalculated daily log summaries for long-term retention. |
| `UptimeMonitor.Metrics.Calculator` | Module | Mathematical helper calculating uptime percentages and latency standard deviations. |
| `UptimeMonitor.Metrics.RollupWorker` | OTP GenServer | Runs scheduled aggregates (every hour) and applies raw check log deletion policies (> 14 days). |
| `UptimeMonitor.StatusPages` | Context | CRUD operations for configuring public status pages. |
| `UptimeMonitor.StatusPages.StatusPage` | Schema | Database settings mapping status page visibility (e.g. `is_public` toggle, slug mappings, custom CSS variables, and visible monitors lists). |
