# Architectural Decision Record (ADR)

## Title: [ADR-0002] OTP Concurrency and Monitoring Workers

*   **Status**: `Accepted`
*   **Date**: 2026-06-20
*   **Author(s)**: Antigravity AI
*   **Deciders**: Diego (USER), Antigravity AI

---

## 1. Context and Problem Statement

To run uptime checks at configurable intervals (e.g. every 30s, 60s, 5m), we need a scheduling engine. The engine must scale to handle thousands of concurrent monitors without degrading performance, consuming excessive network resources, or failing globally if a single target check crashes.

*   **Requirements**:
    *   Sub-second scheduling accuracy.
    *   Strong fault isolation: a failure in one network request must not affect other checks.
    *   Instant configuration update reaction (e.g. pausing, resuming, or deleting a monitor must immediately affect its execution).
*   **Constraints**:
    *   OS limits on open files and network sockets.
    *   BEAM scheduler constraints.

---

## 2. Alternatives Considered

### Alternative A: Database Polling with Background Workers (e.g. Oban / Quantum)
A background worker pool runs on a schedule. It queries the database for monitors that are "due" for a check, inserts execution jobs into a queue, and processes them.

*   **Pros**:
    *   Persisted queue: easy to track execution history and scale across multiple nodes.
    *   No persistent memory overhead from long-running worker processes.
*   **Cons**:
    *   High database load from constant polling, especially at high checking frequencies (e.g. 30s).
    *   Delayed updates: pausing a monitor requires updating the DB and waiting for the next poll cycle to skip it.

### Alternative B: OTP Actor Model (GenServer-per-Monitor inside a DynamicSupervisor)
Every active monitor is represented by a long-running Elixir GenServer. The GenServer uses `:timer.send_interval` or self-messaging (`Process.send_after/3`) to tick at the exact requested frequency. On tick, it spawns a non-blocking `Task` to execute the HTTP request.

*   **Pros**:
    *   Zero database polling: schedules are kept in-memory.
    *   Extreme responsiveness: starting, pausing, or updating a monitor is done instantly via message passing to the GenServer.
    *   Complete isolation: each worker process operates independently.
*   **Cons**:
    *   High process count in Erlang VM (though BEAM is optimized to handle millions of processes, it requires monitoring memory usage).
    *   State is in-memory; restarting the node requires reloading monitor configurations from the database.

---

## 3. Decision Outcome

**Chosen Option**: **Alternative B: OTP Actor Model (GenServer-per-Monitor inside a DynamicSupervisor)**

### Rationale:
*   **BEAM Strength**: The Erlang VM's lightweight process model is ideally suited for this actor-per-monitored-target paradigm. A process crash is completely isolated, ensuring overall platform stability.
*   **Efficiency**: Eliminating database polling drastically reduces disk I/O and query count on PostgreSQL, freeing up DB resources.
*   **Reactivity**: Real-time status changes (pausing, resuming, changing check intervals) take effect instantaneously by interacting directly with the active worker GenServer.

---

## 4. Consequences and Trade-offs

*   **Positive (Good)**:
    *   Sub-millisecond scheduling latency.
    *   Isolated, crash-safe workers.
    *   Simple, real-time control via process messaging.
*   **Negative (Bad/Risks)**:
    *   Node failure destroys in-memory schedule states (mitigated by loading all active monitors from the database during the `Engine` supervisor boot sequence).
*   **Neutral (Neutral)**:
    *   Memory footprint scales linearly with the number of monitors (approx. 2-5KB per active monitor process).

---

## 5. References and Links

*   [System Spec 02: Monitoring Engine & Integrity Checks](file:///C:/Users/Diego/work/Uptime-Monitor/Uptime-Monitor/docs/specs/02_monitoring_engine.md)
*   [Phoenix DynamicSupervisor Docs](https://hexdocs.pm/elixir/DynamicSupervisor.html)
