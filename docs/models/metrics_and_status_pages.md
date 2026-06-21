# Metrics & StatusPages Domain Ecto Schemas

This document defines the Ecto schema mapping, fields, database indexes, and changeset validation rules for the `HourlyRollup`, `DailyRollup`, and `StatusPage` models.

---

## 1. Schema: `UptimeMonitor.Metrics.HourlyRollup`

Aggregated monitor statistics calculated every hour.

### Database Details
*   **Table Name**: `hourly_rollups`
*   **Indexes**:
    *   `create unique_index(:hourly_rollups, [:monitor_id, :hour])` - Prevents duplicate rollup logs.

### Ecto Schema
```elixir
schema "hourly_rollups" do
  field :hour, :utc_datetime
  field :total_checks, :integer
  field :failed_checks, :integer
  field :total_latency_ms, :integer

  belongs_to :monitor, UptimeMonitor.Monitors.Monitor

  timestamps(type: :utc_datetime, updated_at: false)
end
```

### Changeset Validations
*   `cast(attrs, [:hour, :total_checks, :failed_checks, :total_latency_ms])`
*   `validate_required([:hour, :total_checks, :failed_checks, :total_latency_ms])`
*   `validate_number(:total_checks, greater_than_or_equal_to: 0)`
*   `validate_number(:failed_checks, greater_than_or_equal_to: 0)`
*   `validate_number(:total_latency_ms, greater_than_or_equal_to: 0)`

---

## 2. Schema: `UptimeMonitor.Metrics.DailyRollup`

Aggregated monitor statistics calculated daily.

### Database Details
*   **Table Name**: `daily_rollups`
*   **Indexes**:
    *   `create unique_index(:daily_rollups, [:monitor_id, :date])`

### Ecto Schema
```elixir
schema "daily_rollups" do
  field :date, :date
  field :total_checks, :integer
  field :failed_checks, :integer
  field :total_latency_ms, :integer

  belongs_to :monitor, UptimeMonitor.Monitors.Monitor

  timestamps(type: :utc_datetime, updated_at: false)
end
```

### Changeset Validations
*   `cast(attrs, [:date, :total_checks, :failed_checks, :total_latency_ms])`
*   `validate_required([:date, :total_checks, :failed_checks, :total_latency_ms])`
*   `validate_number(:total_checks, greater_than_or_equal_to: 0)`
*   `validate_number(:failed_checks, greater_than_or_equal_to: 0)`
*   `validate_number(:total_latency_ms, greater_than_or_equal_to: 0)`

---

## 3. Schema: `UptimeMonitor.StatusPages.StatusPage`

Configuration details for public status grids.

### Database Details
*   **Table Name**: `status_pages`
*   **Indexes**:
    *   `create unique_index(:status_pages, [:slug])`
    *   `create index(:status_pages, [:tenant_id])`

### Ecto Schema
```elixir
schema "status_pages" do
  field :title, :string
  field :slug, :string
  field :is_public, :boolean, default: true
  field :visible_monitor_ids, {:array, :integer}, default: []

  belongs_to :tenant, UptimeMonitor.Accounts.Tenant

  timestamps(type: :utc_datetime)
end
```

### Changeset Validations
*   `cast(attrs, [:title, :slug, :is_public, :visible_monitor_ids])`
*   `validate_required([:title, :slug])`
*   `validate_format(:slug, ~r/^[a-z0-9\-]+$/)`
*   `unique_constraint(:slug)`
