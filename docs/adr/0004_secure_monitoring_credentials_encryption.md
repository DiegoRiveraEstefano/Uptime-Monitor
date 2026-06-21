# Architectural Decision Record (ADR)

## Title: [ADR-0004] Secure Monitoring Credentials Encryption

*   **Status**: `Accepted`
*   **Date**: 2026-06-20
*   **Author(s)**: Antigravity AI
*   **Deciders**: Diego (USER), Antigravity AI

---

## 1. Context and Problem Statement

Uptime targets often require sensitive authentication parameters to be checked, such as API keys, custom headers, bearer tokens, or query parameter credentials. Storing these headers in raw text in PostgreSQL is insecure and represents a compliance risk (e.g. data leaks in database backups or exports). We need to determine how to securely store and access these secrets.

*   **Requirements**:
    *   Secrets must be encrypted at rest in PostgreSQL.
    *   Decrypted secrets must only reside in memory during check execution.
    *   Low operational overhead.
*   **Constraints**:
    *   No external paid hardware security module (HSM) dependencies in early-stage development.
*   **Assumptions**:
    *   Standard symmetric key cryptography is sufficient for initial protection.

---

## 2. Alternatives Considered

### Alternative A: Raw Text Storage
Store request headers in a standard JSONB column without encryption.

*   **Pros**:
    *   Easiest to implement.
    *   Allows direct database queries on header values.
*   **Cons**:
    *   Highly insecure: anyone with database read access can steal target API keys and credentials.

### Alternative B: External Secret Vault Service (e.g. HashiCorp Vault)
Delegate secret management to an external dedicated secrets manager. The application stores references to secrets in PostgreSQL, and queries Vault during check execution.

*   **Pros**:
    *   Strongest security: centralized control, key rotation, audits.
*   **Cons**:
    *   High operational complexity: adds another dependency that must be run, scaled, and backed up.
    *   Performance latency: adds network requests to retrieve secrets for every tick of the monitoring worker.

### Alternative C: Application-Level Encryption in Ecto (AES-256-GCM)
Encrypt sensitive fields at the application level before saving them to the database. We use a key defined in application environment variables (or runtime config) and encrypt/decrypt using AES-256-GCM (e.g., via `Cloak` or custom Ecto Types).

*   **Pros**:
    *   Excellent balance of security and complexity: database compromises only leak encrypted values.
    *   Zero network latency during check execution (decryption happens locally in-memory).
    *   No external infrastructure dependencies.
*   **Cons**:
    *   Key rotation must be managed by the application.
    *   Header fields cannot be queried directly using SQL inside the database.

---

## 3. Decision Outcome

**Chosen Option**: **Alternative C: Application-Level Encryption in Ecto (AES-256-GCM)**

### Rationale:
*   **Minimal Latency**: Active monitoring checks must execute quickly. Decrypting locally in-memory using Erlang's `:crypto` functions avoids external API calls to get secrets.
*   **Simplicity**: It doesn't require setting up and maintaining HashiCorp Vault, making it easy to run locally or deploy to cloud environments.
*   **Security compliance**: Data at rest in PostgreSQL remains encrypted, shielding customer API keys from snapshot leaks or database unauthorized accesses.

---

## 4. Consequences and Trade-offs

*   **Positive (Good)**:
    *   Secure secrets storage at rest.
    *   Zero external infrastructure footprint.
*   **Negative (Bad/Risks)**:
    *   Secret keys must be securely injected at runtime (e.g., using `System.get_env/1`). Losing the encryption key renders database records unreadable.
*   **Neutral (Neutral)**:
    *   Requires writing or integrating an Ecto type wrapper to automatically encrypt/decrypt headers when mapping fields to schema structs.

---

## 5. References and Links

*   [System Spec 02: Monitoring Engine & Integrity Checks](file:///C:/Users/Diego/work/Uptime-Monitor/Uptime-Monitor/docs/specs/02_monitoring_engine.md)
*   [Elixir Crypto Module](https://www.erlang.org/doc/apps/crypto/crypto.html)
