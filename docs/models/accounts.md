# Accounts Domain Ecto Schemas

This document defines the Ecto schema mapping, fields, database indexes, and changeset validation rules for the `User`, `Tenant`, and `Membership` models.

---

## 1. Schema: `UptimeMonitor.Accounts.User`

Represents the authentication credentials and global identity profile of an individual.

### Database Details
*   **Table Name**: `users`
*   **Indexes**:
    *   `create unique_index(:users, [:email])`

### Ecto Schema
```elixir
schema "users" do
  field :email, :string
  field :password_hash, :string
  field :is_active, :boolean, default: true

  has_many :memberships, UptimeMonitor.Accounts.Membership

  timestamps(type: :utc_datetime)
end
```

### Changeset Validations
*   `cast(attrs, [:email, :password, :is_active])` (Note: `:password` is a virtual field).
*   `validate_required([:email, :password])`
*   `validate_format(:email, ~r/^[^\s]+@[^\s]+$/)`
*   `validate_length(:password, min: 8)`
*   `unique_constraint(:email)`
*   *Hashing Trigger*: Executes Bcrypt password hashing on the virtual `:password` field and stores the output in `:password_hash`.

---

## 2. Schema: `UptimeMonitor.Accounts.Tenant`

Represents an isolated organization workspace.

### Database Details
*   **Table Name**: `tenants`
*   **Indexes**:
    *   `create unique_index(:tenants, [:slug])`

### Ecto Schema
```elixir
schema "tenants" do
  field :name, :string
  field :slug, :string

  has_many :memberships, UptimeMonitor.Accounts.Membership
  has_many :monitors, UptimeMonitor.Monitors.Monitor

  timestamps(type: :utc_datetime)
end
```

### Changeset Validations
*   `cast(attrs, [:name, :slug])`
*   `validate_required([:name, :slug])`
*   `validate_format(:slug, ~r/^[a-z0-9\-]+$/)` - Enforces lowercase letters, numbers, and hyphens.
*   `unique_constraint(:slug)`

---

## 3. Schema: `UptimeMonitor.Accounts.Membership`

Join table associating a user identity with a tenant workspace, storing authorization roles.

### Database Details
*   **Table Name**: `memberships`
*   **Indexes**:
    *   `create unique_index(:memberships, [:tenant_id, :user_id])`
    *   `create index(:memberships, [:user_id])`

### Ecto Schema
```elixir
schema "memberships" do
  field :role, :string

  belongs_to :user, UptimeMonitor.Accounts.User
  belongs_to :tenant, UptimeMonitor.Accounts.Tenant

  timestamps(type: :utc_datetime)
end
```

### Changeset Validations
*   `cast(attrs, [:role])` (Note: `:user_id` and `:tenant_id` are configured programmatically upon insertion to prevent parameters hijacking).
*   `validate_required([:role])`
*   `validate_inclusion(:role, ["owner", "admin", "editor", "viewer"])`
*   `unique_constraint([:tenant_id, :user_id], message: "User is already a member of this tenant")`
