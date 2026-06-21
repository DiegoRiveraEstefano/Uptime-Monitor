defmodule UptimeMonitor.Repo.Migrations.CreateMetricsAndStatusPages do
  use Ecto.Migration

  def change do
    create table(:hourly_rollups) do
      add :hour, :utc_datetime, null: false
      add :total_checks, :integer, null: false
      add :failed_checks, :integer, null: false
      add :total_latency_ms, :integer, null: false
      add :monitor_id, references(:monitors, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:hourly_rollups, [:monitor_id, :hour])

    create table(:daily_rollups) do
      add :date, :date, null: false
      add :total_checks, :integer, null: false
      add :failed_checks, :integer, null: false
      add :total_latency_ms, :integer, null: false
      add :monitor_id, references(:monitors, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:daily_rollups, [:monitor_id, :date])

    create table(:status_pages) do
      add :title, :string, null: false
      add :slug, :string, null: false
      add :is_public, :boolean, default: true, null: false
      add :visible_monitor_ids, {:array, :integer}, default: [], null: false
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:status_pages, [:slug])
    create index(:status_pages, [:tenant_id])
  end
end
