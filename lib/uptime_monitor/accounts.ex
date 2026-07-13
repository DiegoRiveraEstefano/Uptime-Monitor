defmodule UptimeMonitor.Accounts do
  @moduledoc """
  The Accounts context. Handles registration, tenant initialization, and user memberships.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias UptimeMonitor.Repo
  alias UptimeMonitor.Accounts.{User, Tenant, Membership}

  # --- User CRUD & Authentication ---

  @doc """
  Registers a new user account.
  """
  @spec register_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single user by ID.
  """
  @spec get_user!(pos_integer()) :: User.t()
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Retrieves a user by email.
  """
  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  @doc """
  Authenticates a user with email and password.
  """
  @spec authenticate_user(String.t(), String.t()) :: {:ok, User.t()} | {:error, :unauthorized}
  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    if user && User.valid_password?(user, password) do
      {:ok, user}
    else
      {:error, :unauthorized}
    end
  end

  # --- Tenant Management & Setup ---

  @doc """
  Creates a tenant workspace and automatically maps the creator user as the tenant's owner.
  Uses Ecto.Multi to guarantee transaction atomicity.
  """
  @spec create_tenant(User.t(), map()) ::
          {:ok, %{tenant: Tenant.t(), membership: Membership.t()}} | {:error, any()}
  def create_tenant(%User{} = user, attrs) do
    Multi.new()
    |> Multi.insert(:tenant, Tenant.changeset(%Tenant{}, attrs))
    |> Multi.insert(:membership, fn %{tenant: tenant} ->
      %Membership{user_id: user.id, tenant_id: tenant.id}
      |> Membership.changeset(%{role: "owner"})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{tenant: tenant, membership: membership}} ->
        {:ok, %{tenant: tenant, membership: membership}}

      {:error, _failed_op, reason, _changes} ->
        {:error, reason}
    end
  end

  @doc """
  Updates a tenant workspace parameters.
  """
  @spec update_tenant(Tenant.t(), map()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
  def update_tenant(%Tenant{} = tenant, attrs) do
    tenant
    |> Tenant.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets a single tenant by ID.
  """
  @spec get_tenant!(pos_integer()) :: Tenant.t()
  def get_tenant!(id), do: Repo.get!(Tenant, id)

  @doc """
  Gets a single tenant by slug.
  """
  @spec get_tenant_by_slug(String.t()) :: Tenant.t() | nil
  def get_tenant_by_slug(slug) when is_binary(slug), do: Repo.get_by(Tenant, slug: slug)

  @doc """
  Lists all tenants where a user holds a membership.
  """
  @spec list_tenants_by_user(User.t()) :: [Tenant.t()]
  def list_tenants_by_user(%User{id: user_id}) do
    Tenant
    |> join(:inner, [t], m in Membership, on: m.tenant_id == t.id)
    |> where([_t, m], m.user_id == ^user_id)
    |> Repo.all()
  end

  # --- Membership & Invites Management ---

  @doc """
  Lists all memberships for a tenant, preloading users.
  """
  @spec list_members(pos_integer()) :: [Membership.t()]
  def list_members(tenant_id) do
    Membership
    |> where([m], m.tenant_id == ^tenant_id)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Gets a user's membership for a specific tenant.
  """
  @spec get_membership(pos_integer(), pos_integer()) :: Membership.t() | nil
  def get_membership(tenant_id, user_id) do
    Repo.get_by(Membership, tenant_id: tenant_id, user_id: user_id)
  end

  @doc """
  Invites/Adds an existing user to a tenant.
  """
  @spec invite_member(Tenant.t(), String.t(), String.t()) ::
          {:ok, Membership.t()} | {:error, any()}
  def invite_member(%Tenant{} = tenant, email, role) when is_binary(email) do
    case get_user_by_email(email) do
      nil ->
        {:error, :user_not_found}

      user ->
        %Membership{user_id: user.id, tenant_id: tenant.id}
        |> Membership.changeset(%{role: role})
        |> Repo.insert()
    end
  end

  @doc """
  Updates a member's role in a tenant.
  """
  @spec update_member_role(Tenant.t(), pos_integer(), String.t()) ::
          {:ok, Membership.t()} | {:error, any()}
  def update_member_role(%Tenant{} = tenant, user_id, new_role) do
    case get_membership(tenant.id, user_id) do
      nil ->
        {:error, :membership_not_found}

      membership ->
        membership
        |> Membership.changeset(%{role: new_role})
        |> Repo.update()
    end
  end

  @doc """
  Removes a member from a tenant.
  """
  @spec remove_member(Tenant.t(), pos_integer()) :: {:ok, Membership.t()} | {:error, any()}
  def remove_member(%Tenant{} = tenant, user_id) do
    case get_membership(tenant.id, user_id) do
      nil ->
        {:error, :membership_not_found}

      membership ->
        if membership.role == "owner" do
          {:error, :cannot_remove_owner}
        else
          Repo.delete(membership)
        end
    end
  end
end
