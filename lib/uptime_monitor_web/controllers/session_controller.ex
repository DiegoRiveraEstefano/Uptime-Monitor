defmodule UptimeMonitorWeb.SessionController do
  use UptimeMonitorWeb, :controller

  alias UptimeMonitor.Accounts

  @doc """
  Handles the login post request.
  """
  def create(conn, %{"login" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> put_flash(:info, "Welcome back!")
        |> redirect_after_login(user)

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: "/login")
    end
  end

  @doc """
  Handles registration and default workspace initialization.
  """
  def register(conn, %{"register" => %{"email" => email, "password" => password}}) do
    # 1. Register User
    case Accounts.register_user(%{email: email, password: password}) do
      {:ok, user} ->
        # 2. Initialize default workspace tenant
        tenant_slug = "my-workspace"

        unique_slug =
          case Accounts.get_tenant_by_slug(tenant_slug) do
            nil -> tenant_slug
            _ -> "#{tenant_slug}-#{:rand.uniform(999)}"
          end

        {:ok, %{tenant: tenant}} =
          Accounts.create_tenant(user, %{name: "My Workspace", slug: unique_slug})

        # 3. Write session cookie
        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> put_flash(:info, "Account created successfully! Welcome to UptimeMonitor.")
        |> redirect(to: ~p"/org/#{tenant.slug}")

      {:error, changeset} ->
        # Format changeset error message
        error_msg =
          Enum.map_join(changeset.errors, ", ", fn {field, {msg, _opts}} ->
            "#{Atom.to_string(field)} #{msg}"
          end)

        conn
        |> put_flash(:error, "Sign up failed: #{error_msg}")
        |> redirect(to: "/register")
    end
  end

  @doc """
  Handles logout.
  """
  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: "/")
  end

  defp redirect_after_login(conn, user) do
    case Accounts.list_tenants_by_user(user) do
      [] ->
        tenant_slug = "my-workspace"

        unique_slug =
          case Accounts.get_tenant_by_slug(tenant_slug) do
            nil -> tenant_slug
            _ -> "#{tenant_slug}-#{:rand.uniform(999)}"
          end

        {:ok, %{tenant: tenant}} =
          Accounts.create_tenant(user, %{name: "My Workspace", slug: unique_slug})

        redirect(conn, to: ~p"/org/#{tenant.slug}")

      [tenant | _] ->
        redirect(conn, to: ~p"/org/#{tenant.slug}")
    end
  end
end
