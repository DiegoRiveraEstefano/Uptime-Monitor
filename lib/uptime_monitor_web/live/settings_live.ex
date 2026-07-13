defmodule UptimeMonitorWeb.SettingsLive do
  @moduledoc """
  Workspace/Tenant management settings page.
  Allows renaming workspaces, managing memberships, and setting up notification integrations.
  """
  use UptimeMonitorWeb, :live_view

  alias UptimeMonitor.{Accounts, Alerts}
  alias UptimeMonitorWeb.UptimeComponents
  alias UptimeMonitorWeb.Layouts

  @impl true
  def mount(%{"tenant_slug" => slug}, session, socket) do
    case get_current_context(session, slug) do
      {:ok, user, tenant, membership} ->
        # Load workspace members and alert channels
        members = Accounts.list_members(tenant.id)
        channels = Alerts.list_notification_channels(tenant.id)

        # Forms setup
        tenant_form = Phoenix.Component.to_form(Accounts.Tenant.changeset(tenant, %{}))
        invite_form = Phoenix.Component.to_form(%{"email" => "", "role" => "viewer"}, as: :invite)

        channel_form =
          Phoenix.Component.to_form(%{"type" => "email", "target" => ""}, as: :channel)

        socket =
          socket
          |> assign(:current_user, user)
          |> assign(:current_tenant, tenant)
          |> assign(:current_role, membership.role)
          |> assign(:members, members)
          |> assign(:channels, channels)
          |> assign(:tenant_form, tenant_form)
          |> assign(:invite_form, invite_form)
          |> assign(:channel_form, channel_form)

        {:ok, socket}

      {:error, _} ->
        {:ok, redirect(socket, to: "/login")}
    end
  end

  @impl true
  def handle_event("save_tenant", %{"tenant" => params}, socket) do
    tenant = socket.assigns.current_tenant

    if socket.assigns.current_role in ["owner", "admin"] do
      case Accounts.update_tenant(tenant, params) do
        {:ok, updated_tenant} ->
          # If slug changed, redirect to the new workspace settings path
          socket =
            socket
            |> put_flash(:info, "Workspace settings saved successfully.")

          if updated_tenant.slug != tenant.slug do
            {:noreply, push_navigate(socket, to: ~p"/org/#{updated_tenant.slug}/settings")}
          else
            {:noreply,
             socket
             |> assign(:current_tenant, updated_tenant)
             |> assign(
               :tenant_form,
               Phoenix.Component.to_form(Accounts.Tenant.changeset(updated_tenant, %{}))
             )}
          end

        {:error, changeset} ->
          {:noreply, assign(socket, tenant_form: Phoenix.Component.to_form(changeset))}
      end
    else
      {:noreply,
       put_flash(socket, :error, "You do not have permissions to modify workspace details.")}
    end
  end

  @impl true
  def handle_event("invite_member", %{"invite" => %{"email" => email, "role" => role}}, socket) do
    tenant = socket.assigns.current_tenant

    if socket.assigns.current_role in ["owner", "admin"] do
      case Accounts.invite_member(tenant, email, role) do
        {:ok, _membership} ->
          members = Accounts.list_members(tenant.id)

          socket =
            socket
            |> assign(:members, members)
            |> assign(
              :invite_form,
              Phoenix.Component.to_form(%{"email" => "", "role" => "viewer"}, as: :invite)
            )
            |> put_flash(:info, "Member successfully added to the workspace.")

          {:noreply, socket}

        {:error, :user_not_found} ->
          {:noreply,
           put_flash(socket, :error, "No registered user found with the email: #{email}")}

        {:error, changeset} ->
          error_msg =
            Enum.map_join(changeset.errors, ", ", fn {field, {msg, _opts}} ->
              "#{Atom.to_string(field)} #{msg}"
            end)

          {:noreply, put_flash(socket, :error, "Could not add member: #{error_msg}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only owners and administrators can invite members.")}
    end
  end

  @impl true
  def handle_event("change_role", %{"user-id" => user_id_str, "role" => new_role}, socket) do
    tenant = socket.assigns.current_tenant
    user_id = String.to_integer(user_id_str)

    if socket.assigns.current_role in ["owner", "admin"] do
      case Accounts.update_member_role(tenant, user_id, new_role) do
        {:ok, _updated} ->
          members = Accounts.list_members(tenant.id)

          {:noreply,
           socket
           |> assign(:members, members)
           |> put_flash(:info, "Member role updated successfully.")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to update role: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have permissions to manage roles.")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"user-id" => user_id_str}, socket) do
    tenant = socket.assigns.current_tenant
    user_id = String.to_integer(user_id_str)

    # Prevent removing self
    if user_id == socket.assigns.current_user.id do
      {:noreply, put_flash(socket, :error, "You cannot remove yourself from the workspace.")}
    else
      if socket.assigns.current_role in ["owner", "admin"] do
        case Accounts.remove_member(tenant, user_id) do
          {:ok, _removed} ->
            members = Accounts.list_members(tenant.id)

            {:noreply,
             socket
             |> assign(:members, members)
             |> put_flash(:info, "Member removed from workspace.")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to remove member: #{inspect(reason)}")}
        end
      else
        {:noreply,
         put_flash(socket, :error, "Only owners and administrators can remove members.")}
      end
    end
  end

  @impl true
  def handle_event("save_channel", %{"channel" => %{"type" => type, "target" => target}}, socket) do
    tenant = socket.assigns.current_tenant

    if socket.assigns.current_role in ["owner", "admin"] do
      config =
        case type do
          "slack" -> %{"webhook_url" => target}
          "email" -> %{"to" => target}
          "webhook" -> %{"url" => target}
          _ -> %{}
        end

      case Alerts.create_notification_channel(tenant, %{type: type, active: true, config: config}) do
        {:ok, _channel} ->
          channels = Alerts.list_notification_channels(tenant.id)

          socket =
            socket
            |> assign(:channels, channels)
            |> assign(
              :channel_form,
              Phoenix.Component.to_form(%{"type" => "email", "target" => ""}, as: :channel)
            )
            |> put_flash(:info, "Alert notification integration added successfully.")

          {:noreply, socket}

        {:error, changeset} ->
          error_msg =
            Enum.map_join(changeset.errors, ", ", fn {field, {msg, _opts}} ->
              "#{Atom.to_string(field)} #{msg}"
            end)

          {:noreply, put_flash(socket, :error, "Failed to create integration: #{error_msg}")}
      end
    else
      {:noreply,
       put_flash(socket, :error, "Only owners and administrators can manage alert channels.")}
    end
  end

  @impl true
  def handle_event("delete_channel", %{"id" => id_str}, socket) do
    tenant = socket.assigns.current_tenant
    channel_id = String.to_integer(id_str)

    if socket.assigns.current_role in ["owner", "admin"] do
      case Alerts.delete_notification_channel(tenant, channel_id) do
        {:ok, _deleted} ->
          channels = Alerts.list_notification_channels(tenant.id)

          {:noreply,
           socket
           |> assign(:channels, channels)
           |> put_flash(:info, "Notification integration deleted.")}

        {:error, reason} ->
          {:noreply,
           put_flash(socket, :error, "Failed to delete integration: #{inspect(reason)}")}
      end
    else
      {:noreply,
       put_flash(socket, :error, "Only owners and administrators can manage alert channels.")}
    end
  end

  # --- Authorization context helper ---
  defp get_current_context(session, slug) do
    user_id = session["user_id"]

    if user_id do
      user = Accounts.get_user!(user_id)
      tenant = Accounts.get_tenant_by_slug(slug)

      if tenant do
        case Accounts.get_membership(tenant.id, user.id) do
          nil -> {:error, :unauthorized}
          membership -> {:ok, user, tenant, membership}
        end
      else
        {:error, :not_found}
      end
    else
      {:error, :unauthenticated}
    end
  end
end
