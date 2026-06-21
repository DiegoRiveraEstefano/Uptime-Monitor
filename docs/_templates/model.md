# Ecto Models & Schemas Design Template

This document defines the schema design, changeset validation practices, database indexing, and multi-tenant scoping strategies for Ecto models in `UptimeMonitor`.

---

## 1. Ecto Guidelines & Constraints

*   **Field Types**: Ecto schema fields must always use the `:string` type, even when the underlying PostgreSQL database column is defined as `text`.
    ```elixir
    # Correct
    field :description, :string
    ```
*   **Changeset Access**: Structs do not implement the `Access` protocol. Never use map access (`changeset[:field]`) on changesets or structs. Use `Ecto.Changeset.get_field(changeset, :field)` or access fields directly on loaded structs (`struct.field`).
*   **No Programmatic Fields in Cast**: Fields that are set programmatically (like `tenant_id`, `user_id`, or system-generated tokens) **must not** be listed in the schema's `cast/3` function. This prevents mass-assignment security vulnerabilities. Instead, assign them explicitly during struct creation or use `Ecto.Changeset.put_change/3`.
*   **Numeric Validations**: `validate_number/3` does not support the `:allow_nil` option. Validations in Ecto only run if the field is present in the changes map, making `:allow_nil` unnecessary.
*   **Migration Generation**: Always invoke `mix ecto.gen.migration migration_name_using_underscores` to apply proper timestamp naming conventions.

---

## 2. Multi-Tenant Indexing Patterns
To guarantee database isolation and sub-millisecond query performance:
*   Every table belonging to a tenant must include a `tenant_id` foreign key.
*   Create compound indexes on `[:tenant_id, :id]` or specific lookup columns (e.g. `[:tenant_id, :url]`) to enforce fast, secure lookups.

---

## 3. Database Migration Example

Below is the standard layout for a migration implementing a multi-tenant `monitors` table:

```elixir
defmodule UptimeMonitor.Repo.Migrations.CreateMonitors do
  use Ecto.Migration

  def change do
    create table(:monitors) do
      add :name, :string, null: false
      add :url, :string, null: false
      add :interval_seconds, :integer, default: 60, null: false
      add :active, :boolean, default: true, null: false
      
      # Foreign Key referencing the Tenant
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    # Compound index for multi-tenant querying efficiency
    create index(:monitors, [:tenant_id])
    create unique_index(:monitors, [:tenant_id, :url])
  end
end
```

---

## 4. Ecto Schema Template Example

Here is the corresponding schema implementation adhering to all guidelines:

```elixir
defmodule UptimeMonitor.Monitors.Monitor do
  use Ecto.Schema
  import Ecto.Changeset

  alias UptimeMonitor.Accounts.Tenant

  # Enforce type specification structure
  @type t :: %__MODULE__{
    id: pos_integer() | nil,
    name: String.t() | nil,
    url: String.t() | nil,
    interval_seconds: pos_integer() | nil,
    active: boolean() | nil,
    tenant_id: pos_integer() | nil,
    tenant: Tenant.t() | Ecto.Association.NotLoaded.t(),
    inserted_at: DateTime.t() | nil,
    updated_at: DateTime.t() | nil
  }

  schema "monitors" do
    field :name, :string
    field :url, :string
    field :interval_seconds, :integer, default: 60
    field :active, :boolean, default: true
    
    belongs_to :tenant, Tenant

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for creating or updating a Monitor.
  Note that :tenant_id is NOT cast to prevent parameter injection.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = monitor, attrs) do
    monitor
    |> cast(attrs, [:name, :url, :interval_seconds, :active])
    |> validate_required([:name, :url])
    |> validate_url(:url)
    |> validate_number(:interval_seconds, greater_than_or_equal_to: 30)
  end

  @doc """
  Special changeset to programmatically pause a monitor.
  """
  @spec pause_changeset(t()) :: Ecto.Changeset.t()
  def pause_changeset(%__MODULE__{} = monitor) do
    change(monitor, active: false)
  end

  # Helper validator (example of custom validations)
  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _field, url ->
      case URI.new(url) do
        {:ok, %URI{scheme: scheme, host: host}} when scheme in ["http", "https"] and not is_nil(host) ->
          []
        _ ->
          [{field, "must be a valid HTTP or HTTPS URL"}]
      end
    end)
  end
end
```
