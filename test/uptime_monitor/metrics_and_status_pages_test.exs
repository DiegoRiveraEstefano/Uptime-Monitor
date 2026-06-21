defmodule UptimeMonitor.MetricsAndStatusPagesTest do
  use UptimeMonitor.DataCase, async: false

  alias UptimeMonitor.Accounts
  alias UptimeMonitor.Monitors
  alias UptimeMonitor.Metrics
  alias UptimeMonitor.Metrics.{HourlyRollup, DailyRollup, Calculator, RollupWorker}
  alias UptimeMonitor.StatusPages
  alias UptimeMonitor.StatusPages.StatusPage

  @tenant_attrs %{name: "Org Metrics", slug: "org-metrics"}
  @monitor_attrs %{name: "Ping Target", url: "https://ping.example.com", interval_seconds: 60, active: false}

  setup do
    {:ok, user} = Accounts.register_user(%{email: "metrics@example.com", password: "password123"})
    {:ok, %{tenant: tenant}} = Accounts.create_tenant(user, @tenant_attrs)
    {:ok, monitor} = Monitors.create_monitor(tenant, @monitor_attrs)
    %{tenant: tenant, monitor: monitor}
  end

  describe "metrics mathematical calculator" do
    test "calculate_uptime/2 returns correct SLA ratio" do
      assert Calculator.calculate_uptime(100, 0) == 100.0
      assert Calculator.calculate_uptime(100, 5) == 95.0
      assert Calculator.calculate_uptime(0, 0) == 100.0
      assert Calculator.calculate_uptime(3, 1) == 66.6667
    end

    test "calculate_average_latency/2 returns correct latency averages" do
      assert Calculator.calculate_average_latency(0, 0) == 0.0
      assert Calculator.calculate_average_latency(4, 1000) == 250.0
    end
  end

  describe "hourly & daily rollups aggregation engine" do
    test "perform_hourly_rollup/1 consolidates raw checks into HourlyRollup", %{monitor: monitor} do
      hour = DateTime.utc_now() |> DateTime.truncate(:second)
      
      # Log check results in database
      {:ok, _} = Monitors.create_check_result(monitor, %{status: "up", latency_ms: 100})
      {:ok, _} = Monitors.create_check_result(monitor, %{status: "up", latency_ms: 150})
      {:ok, _} = Monitors.create_check_result(monitor, %{status: "down", latency_ms: 50})

      # Run rollup worker manually for this hour
      assert :ok = RollupWorker.perform_hourly_rollup(hour)

      # Check hourly rollup table
      assert %HourlyRollup{} = rollup = Repo.get_by(HourlyRollup, monitor_id: monitor.id)
      assert rollup.total_checks == 3
      assert rollup.failed_checks == 1
      assert rollup.total_latency_ms == 300
    end

    test "perform_daily_rollup/1 compiles daily statistics from hourly stats", %{monitor: monitor} do
      date = Date.utc_today()
      hour = DateTime.new!(date, ~T[12:00:00], "Etc/UTC")

      # Insert mock hourly stats
      %HourlyRollup{}
      |> HourlyRollup.changeset(%{
        monitor_id: monitor.id,
        hour: hour,
        total_checks: 10,
        failed_checks: 2,
        total_latency_ms: 2000
      })
      |> Repo.insert!()

      assert :ok = RollupWorker.perform_daily_rollup(date)

      assert %DailyRollup{} = rollup = Repo.get_by(DailyRollup, monitor_id: monitor.id)
      assert rollup.total_checks == 10
      assert rollup.failed_checks == 2
      assert rollup.total_latency_ms == 2000
    end
  end

  describe "metrics context SLA retrievals" do
    setup %{monitor: monitor} do
      date = Date.utc_today()
      
      # Insert daily rollup mock
      %DailyRollup{}
      |> DailyRollup.changeset(%{
        monitor_id: monitor.id,
        date: date,
        total_checks: 100,
        failed_checks: 1,
        total_latency_ms: 15000
      })
      |> Repo.insert!()

      :ok
    end

    test "get_uptime_percentage/2 calculates SLA from daily rollup table", %{monitor: monitor} do
      assert Metrics.get_uptime_percentage(monitor, 7) == 99.0
    end

    test "get_average_latency/2 calculates average latency from daily rollup table", %{monitor: monitor} do
      assert Metrics.get_average_latency(monitor, 7) == 150.0
    end
  end

  describe "status pages CRUD and slug lookup" do
    test "create_status_page/2 inserts a page linked to the tenant", %{tenant: tenant, monitor: monitor} do
      attrs = %{
        title: "ACME Live Status",
        slug: "acme-live",
        is_public: true,
        visible_monitor_ids: [monitor.id]
      }

      assert {:ok, %StatusPage{} = page} = StatusPages.create_status_page(tenant, attrs)
      assert page.title == "ACME Live Status"
      assert page.slug == "acme-live"
      assert page.is_public == true
      assert page.visible_monitor_ids == [monitor.id]

      # Read lookup by slug
      assert {:ok, found} = StatusPages.get_status_page_by_slug("acme-live")
      assert found.id == page.id
    end
  end
end
