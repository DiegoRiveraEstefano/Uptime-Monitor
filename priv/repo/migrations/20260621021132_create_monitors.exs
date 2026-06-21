defmodule UptimeMonitor.Repo.Migrations.CreateMonitors do
  use Ecto.Migration

  def change do
    create table(:monitors) do
      add :name, :string, null: false
      add :url, :string, null: false
      add :interval_seconds, :integer, default: 60, null: false
      add :active, :boolean, default: true, null: false
      add :encrypted_headers, :map, null: false, default: "{}"
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:monitors, [:tenant_id])
    create unique_index(:monitors, [:tenant_id, :url])

    create table(:heartbeats) do
      add :name, :string, null: false
      add :token, :string, null: false
      add :expected_interval_seconds, :integer, default: 86400, null: false
      add :grace_period_seconds, :integer, default: 900, null: false
      add :last_pinged_at, :utc_datetime
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:heartbeats, [:tenant_id])
    create unique_index(:heartbeats, [:token])

    create table(:check_results) do
      add :status, :string, null: false
      add :latency_ms, :integer, null: false
      add :response_code, :integer
      add :debug_response_body, :text
      add :monitor_id, references(:monitors, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:check_results, [:monitor_id, :inserted_at])
  end
end
