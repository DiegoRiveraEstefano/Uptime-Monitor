# Architectural Decision Record (ADR) Template

## Title: [ADR-XXXX] [Short, Descriptive Title of the Decision]

*   **Status**: `Proposed` | `Accepted` | `Rejected` | `Superseded by [ADR-YYYY]`
*   **Date**: YYYY-MM-DD
*   **Author(s)**: [Author Name]
*   **Deciders**: [List of key stakeholders/decision-makers]

---

## 1. Context and Problem Statement

*Describe the context, the business/technical problem we are trying to solve, and the requirements or constraints. What is the current situation? Why are we discussing this now?*

*   **Requirements**: [e.g., must scale to 10k concurrent checks, must guarantee strict multi-tenant isolation]
*   **Constraints**: [e.g., PostgreSQL database, memory limits on BEAM]
*   **Assumptions**: [e.g., users will mostly query current uptime status, not historical aggregates of 5 years]

---

## 2. Alternatives Considered

*Outline the potential solutions that were evaluated. For each alternative, list the pros and cons.*

### Alternative A: [Name of Alternative]
*   **Pros**:
    *   [Pro 1]
    *   [Pro 2]
*   **Cons**:
    *   [Con 1]
    *   [Con 2]

### Alternative B: [Name of Alternative]
*   **Pros**:
    *   ...
*   **Cons**:
    *   ...

---

## 3. Decision Outcome

*State the chosen alternative, the rationale behind the decision, and how it solves the problem statement.*

**Chosen Option**: **[Alternative A / Alternative B / Hybrid]**

### Rationale:
*   [Key Reason 1]
*   [Key Reason 2]

---

## 4. Consequences and Trade-offs

*What happens now that this decision is made? What are the positive, negative, and neutral effects of this decision on the codebase, performance, operations, and development speed?*

*   **Positive (Good)**:
    *   [Positive Effect 1]
*   **Negative (Bad/Risks)**:
    *   [Negative Effect / Tech Debt / Trade-off 1]
*   **Neutral (Neutral)**:
    *   [Operational changes, adjustments, learning curve]

---

## 5. References and Links

*Include links to relevant documentation, issues, pull requests, other ADRs, or external articles.*

*   [ADR-0001: Initial Multi-Tenancy Strategy]
*   [Phoenix LiveView Stream Docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-streams)
