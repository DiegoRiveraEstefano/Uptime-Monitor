# Monitors Domain Ecto Schemas

This document defines the Ecto schema mapping, fields, database indexes, and changeset validation rules for the `Monitor`, `Heartbeat`, and `CheckResult` models.

---

## 1. Schema: `UptimeMonitor.Monitors.Monitor`

Represents an active HTTP/HTTPS endpoint check configuration.

### Database Details
*   **Table Name**: `monitors`
*   **Indexes**:
    *   `create index(:monitors, [:tenant_id])`
    *   `create unique_index(:monitors, [:tenant_id, :url])` - Prevents duplicate target configurations within the same tenant.

### Ecto Schema
```elixir
schema "monitors" do
  field :name, :string
  field :url, :string
  field :interval_seconds, :integer, default: 60
  field :active, :boolean, default: true
  field :encrypted_headers, :map, default: %{}

  belongs_to :tenant, UptimeMonitor.Accounts.Tenant
  has_many :check_results, UptimeMonitor.Monitors.CheckResult
  has_many :incidents, UptimeMonitor.Incidents.Incident

  timestamps(type: :utc_datetime)
end
```

### Changeset Validations
*   `cast(attrs, [:name, :url, :interval_seconds, :active, :encrypted_headers])` (Note: `:tenant_id` must be explicitly loaded or set programmatically, never cast).
*   `validate_required([:name, :url])`
*   `validate_number(:interval_seconds, greater_than_or_equal_to: 30, message: "must be at least 30 seconds")`
*   `validate_format(:url, ~r/^https?:\/\/[^\s]+$/)` - Enforces standard HTTP or HTTPS schemes.
*   `unique_constraint([:tenant_id, :url], message: "This URL is already being monitored in this workspace")`

---

## 2. Schema: `UptimeMonitor.Monitors.Heartbeat`

Represents a passive endpoint tracking cronjobs or external heartbeat integrations.

### Database Details
*   **Table Name**: `heartbeats`
*   **Indexes**:
    *   `create index(:heartbeats, [:tenant_id])`
    *   `create unique_index(:heartbeats, [:token])`

### Ecto Schema
```elixir
schema "heartbeats" do
  field :name, :string
  field :token, :string
  field :expected_interval_seconds, :integer, default: 86400
  field :grace_period_seconds, :integer, default: 900
  field :last_pinged_at, :utc_datetime

  belongs_to :tenant, UptimeMonitor.Accounts.Tenant

  timestamps(type: :utc_datetime)
end
```

### Changeset Validations
*   `cast(attrs, [:name, :expected_interval_seconds, :grace_period_seconds])`
*   `validate_required([:name])`
*   `validate_number(:expected_interval_seconds, greater_than: 0)`
*   `validate_number(:grace_period_seconds, greater_than_or_equal_to: 0)`
*   *Key Generation Trigger*: Automatically generates a secure random token in the changeset if not already present.

---

## 3. Schema: `UptimeMonitor.Monitors.CheckResult`

Stores diagnostic logs for each check. Due to data volume, a retention script purges these rows after 14 days.

### Database Details
*   **Table Name**: `check_results`
*   **Indexes**:
    *   `create index(:check_results, [:monitor_id, :inserted_at])`

### Ecto Schema
```elixir
schema "check_results" do
  field :status, :string
  field :latency_ms, :integer
  field :response_code, :integer
  field :debug_response_body, :string

  belongs_to :monitor, UptimeMonitor.Monitors.Monitor

  timestamps(type: :utc_datetime, updated_at: false) # updated_at is disabled
end
```

### Changeset Validations
*   `cast(attrs, [:status, :latency_ms, :response_code, :debug_response_body])`
*   `validate_required([:status, :latency_ms])`
*   `validate_inclusion(:status, ["up", "down"])`
*   `validate_number(:latency_ms, greater_than_or_equal_to: 0)`
*   *Payload Truncation*: Custom changeset hook truncates `:debug_response_body` values exceeding 2048 characters prior to database insertion.
