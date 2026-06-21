defmodule UptimeMonitor.Repo.Migrations.CreateIncidentsAndAlerts do
  use Ecto.Migration

  def change do
    create table(:incidents) do
      add :status, :string, default: "open", null: false
      add :opened_at, :utc_datetime, null: false
      add :resolved_at, :utc_datetime
      add :downtime_seconds, :integer
      add :monitor_id, references(:monitors, on_delete: :delete_all), null: false
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:incidents, [:tenant_id])
    create index(:incidents, [:monitor_id, :status])

    create table(:post_mortems) do
      add :title, :string, null: false
      add :content, :text, null: false
      add :incident_id, references(:incidents, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:post_mortems, [:incident_id])

    create table(:notification_channels) do
      add :type, :string, null: false
      add :active, :boolean, default: true, null: false
      add :config, :map, null: false, default: "{}"
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:notification_channels, [:tenant_id])

    create table(:platform_notifications) do
      add :title, :string, null: false
      add :message, :string, null: false
      add :read, :boolean, default: false, null: false
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:platform_notifications, [:tenant_id, :read])
  end
end
