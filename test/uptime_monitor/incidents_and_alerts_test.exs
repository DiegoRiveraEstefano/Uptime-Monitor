defmodule UptimeMonitor.IncidentsAndAlertsTest do
  use UptimeMonitor.DataCase, async: false # Async false because we test async dispatch processes

  alias UptimeMonitor.Accounts
  alias UptimeMonitor.Monitors
  alias UptimeMonitor.Incidents
  alias UptimeMonitor.Incidents.{Incident, PostMortem}
  alias UptimeMonitor.Alerts
  alias UptimeMonitor.Alerts.{NotificationChannel, PlatformNotification}

  @tenant_attrs %{name: "Org Alerts", slug: "org-alerts"}
  @monitor_attrs %{name: "Test Server", url: "https://test.domain.com", interval_seconds: 60, active: false}

  setup do
    {:ok, user} = Accounts.register_user(%{email: "alerts@example.com", password: "password123"})
    {:ok, %{tenant: tenant}} = Accounts.create_tenant(user, @tenant_attrs)
    {:ok, monitor} = Monitors.create_monitor(tenant, @monitor_attrs)
    %{user: user, tenant: tenant, monitor: monitor}
  end

  describe "incident lifecycle & alert grouping" do
    test "report_failure/2 creates an open incident on first failure", %{monitor: monitor} do
      assert {:ok, %Incident{} = incident} = Incidents.report_failure(monitor, "Connection Timeout")
      assert incident.status == "open"
      assert incident.opened_at != nil
      assert incident.resolved_at == nil
      assert incident.monitor_id == monitor.id
    end

    test "report_failure/2 groups subsequent failures under the same open incident", %{monitor: monitor} do
      {:ok, incident_first} = Incidents.report_failure(monitor, "Connection Timeout")
      
      # Next failure returns the exact same incident (grouping active)
      assert {:ok, incident_second} = Incidents.report_failure(monitor, "502 Bad Gateway")
      assert incident_second.id == incident_first.id
    end

    test "report_recovery/1 resolves the active incident, calculates downtime, and resolves alerts", %{monitor: monitor} do
      {:ok, _incident} = Incidents.report_failure(monitor, "Outage")
      
      # Wait a tiny bit to get downtime diff
      Process.sleep(1000)

      assert {:ok, resolved} = Incidents.report_recovery(monitor)
      assert resolved.status == "resolved"
      assert resolved.resolved_at != nil
      assert resolved.downtime_seconds >= 1
    end

    test "report_recovery/1 returns error if there is no active incident", %{monitor: monitor} do
      assert {:error, :no_active_incident} = Incidents.report_recovery(monitor)
    end
  end

  describe "incident post-mortems" do
    setup %{user: user, tenant: tenant, monitor: monitor} do
      {:ok, incident} = Incidents.report_failure(monitor, "Outage")
      {:ok, resolved} = Incidents.report_recovery(monitor)
      %{user: user, incident: resolved}
    end

    test "create_post_mortem/3 logs markdown document attached to incident", %{user: user, incident: incident} do
      attrs = %{
        title: "Database connection pool exhaustion",
        content: "Root Cause: Max connections reached in Repo.\nMitigation: Raised connection pool size in config."
      }

      assert {:ok, %PostMortem{} = pm} = Incidents.create_post_mortem(user, incident, attrs)
      assert pm.incident_id == incident.id
      assert pm.created_by_id == user.id
      assert pm.title == "Database connection pool exhaustion"
    end
  end

  describe "notification channels & integrations" do
    test "create_notification_channel/2 saves settings and validates details based on type", %{tenant: tenant} do
      # Platform channel
      assert {:ok, %NotificationChannel{} = chan1} = Alerts.create_notification_channel(tenant, %{
        type: "platform",
        active: true,
        config: %{}
      })
      assert chan1.type == "platform"

      # Email channel validation success
      assert {:ok, _} = Alerts.create_notification_channel(tenant, %{
        type: "email",
        config: %{"to" => "alerts@example.com"}
      })

      # Email channel validation error
      assert {:error, changeset} = Alerts.create_notification_channel(tenant, %{
        type: "email",
        config: %{"to" => "bad_email_format"}
      })
      assert errors_on(changeset)[:config] == ["must specify a valid target email address"]

      # Slack channel validation error
      assert {:error, changeset} = Alerts.create_notification_channel(tenant, %{
        type: "slack",
        config: %{"webhook_url" => "http://badurl"}
      })
      assert errors_on(changeset)[:config] == ["must contain a valid Slack webhook URL starting with https://hooks.slack.com/"]
    end
  end

  describe "platform built-in alerts" do
    test "in-app notifications are logged and can be marked as read", %{tenant: tenant} do
      {:ok, notif} = Alerts.create_platform_notification(tenant.id, %{
        title: "Alert",
        message: "Outage detected."
      })
      refute notif.read

      assert {:ok, updated} = Alerts.mark_notification_as_read(tenant.id, notif.id)
      assert updated.read
    end
  end
end
