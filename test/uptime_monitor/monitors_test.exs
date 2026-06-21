defmodule UptimeMonitor.MonitorsTest do
  use UptimeMonitor.DataCase, async: false # Async false because OTP GenServers register globally

  alias UptimeMonitor.Monitors
  alias UptimeMonitor.Monitors.{Monitor, Heartbeat, CheckResult}
  alias UptimeMonitor.Accounts

  @tenant_attrs %{name: "ACME Monitoring", slug: "acme-monitoring"}
  @valid_monitor_attrs %{name: "Acme Web", url: "https://example.com", interval_seconds: 60}
  @invalid_monitor_attrs %{name: "", url: "not_a_url", interval_seconds: 15}

  setup do
    # Suppress worker logs during test if necessary, or just start dependencies
    {:ok, user} = Accounts.register_user(%{email: "owner@example.com", password: "password123"})
    {:ok, %{tenant: tenant}} = Accounts.create_tenant(user, @tenant_attrs)
    %{tenant: tenant}
  end

  describe "monitors lifecycle and context" do
    test "create_monitor/2 with valid attributes stores monitor and starts engine worker", %{tenant: tenant} do
      assert {:ok, %Monitor{} = monitor} = Monitors.create_monitor(tenant, @valid_monitor_attrs)
      assert monitor.name == "Acme Web"
      assert monitor.url == "https://example.com"
      assert monitor.interval_seconds == 60
      assert monitor.active == true
      
      # Clean up active worker
      assert :ok = Monitors.Engine.deregister(monitor)
    end

    test "create_monitor/2 with invalid attributes returns error changeset", %{tenant: tenant} do
      assert {:error, %Ecto.Changeset{} = changeset} = Monitors.create_monitor(tenant, @invalid_monitor_attrs)
      assert errors_on(changeset)[:name] == ["can't be blank"]
      assert errors_on(changeset)[:url] == ["must be a valid HTTP or HTTPS URL"]
      assert errors_on(changeset)[:interval_seconds] == ["must be greater than or equal to 30"]
    end

    test "pause_monitor/2 and resume_monitor/2 toggle active flag and trigger engine actions", %{tenant: tenant} do
      {:ok, monitor} = Monitors.create_monitor(tenant, @valid_monitor_attrs)
      
      # Pause
      assert {:ok, paused} = Monitors.pause_monitor(tenant, monitor)
      refute paused.active
      
      # Resume
      assert {:ok, resumed} = Monitors.resume_monitor(tenant, paused)
      assert resumed.active

      # Clean up active worker
      assert :ok = Monitors.Engine.deregister(resumed)
    end

    test "delete_monitor/2 removes monitor from database and stops engine worker", %{tenant: tenant} do
      {:ok, monitor} = Monitors.create_monitor(tenant, @valid_monitor_attrs)
      assert {:ok, deleted} = Monitors.delete_monitor(tenant, monitor)
      assert {:error, :not_found} = Monitors.get_monitor(tenant.id, deleted.id)
    end
  end

  describe "check results logging" do
    setup %{tenant: tenant} do
      # Create inactive monitor to avoid background tick timers firing during tests
      {:ok, monitor} = Monitors.create_monitor(tenant, Map.put(@valid_monitor_attrs, :active, false))
      %{monitor: monitor}
    end

    test "create_check_result/2 creates a log and truncates very long debug body snippets", %{monitor: monitor} do
      long_body = String.duplicate("A", 3000)
      
      assert {:ok, %CheckResult{} = result} = Monitors.create_check_result(monitor, %{
        status: "down",
        latency_ms: 120,
        response_code: 502,
        debug_response_body: long_body
      })

      assert result.status == "down"
      assert result.latency_ms == 120
      assert result.response_code == 502
      assert String.length(result.debug_response_body) == 2048
      assert String.starts_with?(result.debug_response_body, "AAAA")
    end
  end

  describe "heartbeats push checks" do
    test "create_heartbeat/2 sets up passive checks with randomized secure tokens", %{tenant: tenant} do
      attrs = %{name: "Backup Cron", expected_interval_seconds: 3600, grace_period_seconds: 300}
      assert {:ok, %Heartbeat{} = hb} = Monitors.create_heartbeat(tenant, attrs)
      
      assert hb.name == "Backup Cron"
      assert hb.expected_interval_seconds == 3600
      assert hb.grace_period_seconds == 300
      assert hb.token != nil
      assert String.length(hb.token) >= 20
    end

    test "ping_heartbeat/1 updates last_pinged_at timestamps", %{tenant: tenant} do
      {:ok, hb} = Monitors.create_heartbeat(tenant, %{name: "Sync Job"})
      assert hb.last_pinged_at == nil

      assert {:ok, updated_hb} = Monitors.ping_heartbeat(hb.token)
      assert updated_hb.last_pinged_at != nil
      
      assert {:error, :not_found} = Monitors.ping_heartbeat("invalid_token")
    end
  end
end
