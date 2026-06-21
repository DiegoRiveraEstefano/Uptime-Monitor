# Incidents & Alerts Domain Ecto Schemas

This document defines the Ecto schema mapping, fields, database indexes, and changeset validation rules for the `Incident`, `PostMortem`, `NotificationChannel`, and `PlatformNotification` models.

---

## 1. Schema: `UptimeMonitor.Incidents.Incident`

Represents a logical grouping of sequential monitor outages.

### Database Details
*   **Table Name**: `incidents`
*   **Indexes**:
    *   `create index(:incidents, [:tenant_id])`
    *   `create index(:incidents, [:monitor_id, :status])`

### Ecto Schema
```elixir
schema "incidents" do
  field :status, :string, default: "open"
  field :opened_at, :utc_datetime
  field :resolved_at, :utc_datetime
  field :downtime_seconds, :integer

  belongs_to :tenant, UptimeMonitor.Accounts.Tenant
  belongs_to :monitor, UptimeMonitor.Monitors.Monitor
  has_one :post_mortem, UptimeMonitor.Incidents.PostMortem

  timestamps(type: :utc_datetime)
end
```

### Changeset Validations
*   `cast(attrs, [:status, :opened_at, :resolved_at, :downtime_seconds])`
*   `validate_required([:status, :opened_at])`
*   `validate_inclusion(:status, ["open", "resolved"])`

---

## 2. Schema: `UptimeMonitor.Incidents.PostMortem`

Markdown analytical review associated with resolved incidents.

### Database Details
*   **Table Name**: `post_mortems`
*   **Indexes**:
    *   `create unique_index(:post_mortems, [:incident_id])`

### Ecto Schema
```elixir
schema "post_mortems" do
  field :title, :string
  field :content, :string # Adhering to guidelines: use :string even for database text/markdown columns.

  belongs_to :incident, UptimeMonitor.Incidents.Incident
  belongs_to :created_by, UptimeMonitor.Accounts.User

  timestamps(type: :utc_datetime)
end
```

### Changeset Validations
*   `cast(attrs, [:title, :content])`
*   `validate_required([:title, :content])`
*   `validate_length(:title, min: 5, max: 255)`
*   `validate_length(:content, min: 20)`

---

## 3. Schema: `UptimeMonitor.Alerts.NotificationChannel`

Integration details for notification endpoints (email, Slack, Webhooks).

### Database Details
*   **Table Name**: `notification_channels`
*   **Indexes**:
    *   `create index(:notification_channels, [:tenant_id])`

### Ecto Schema
```elixir
schema "notification_channels" do
  field :type, :string
  field :active, :boolean, default: true
  field :config, :map, default: %{}

  belongs_to :tenant, UptimeMonitor.Accounts.Tenant

  timestamps(type: :utc_datetime)
end
```

### Changeset Validations
*   `cast(attrs, [:type, :active, :config])`
*   `validate_required([:type, :active, :config])`
*   `validate_inclusion(:type, ["platform", "email", "slack", "webhook"])`
*   *Config Validation*: Custom validator verifies structure mapping based on adapter type (e.g. checks for valid Slack webhook URL syntax when `type == "slack"`).

---

## 4. Schema: `UptimeMonitor.Alerts.PlatformNotification`

Stores database-level notifications shown in the web console alert inbox.

### Database Details
*   **Table Name**: `platform_notifications`
*   **Indexes**:
    *   `create index(:platform_notifications, [:tenant_id, :read])`

### Ecto Schema
```elixir
schema "platform_notifications" do
  field :title, :string
  field :message, :string
  field :read, :boolean, default: false

  belongs_to :tenant, UptimeMonitor.Accounts.Tenant

  timestamps(type: :utc_datetime, updated_at: false)
end
```

### Changeset Validations
*   `cast(attrs, [:title, :message, :read])`
*   `validate_required([:title, :message])`
