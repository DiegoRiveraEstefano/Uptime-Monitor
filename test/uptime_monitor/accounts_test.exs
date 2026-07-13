defmodule UptimeMonitor.AccountsTest do
  use UptimeMonitor.DataCase, async: true

  alias UptimeMonitor.Accounts
  alias UptimeMonitor.Accounts.{User, Tenant, Membership}

  @valid_user_attrs %{email: "user@example.com", password: "password123"}
  @invalid_user_attrs %{email: "invalid_email", password: "123"}
  @tenant_attrs %{name: "ACME Corp", slug: "acme-corp"}

  describe "users registration & authentication" do
    test "register_user/1 with valid attributes creates a user with hashed password" do
      assert {:ok, %User{} = user} = Accounts.register_user(@valid_user_attrs)
      assert user.email == "user@example.com"
      assert user.password_hash != nil
      assert user.password_hash != "password123"
      assert Accounts.User.valid_password?(user, "password123")
      refute Accounts.User.valid_password?(user, "wrongpassword")
    end

    test "register_user/1 with invalid attributes returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.register_user(@invalid_user_attrs)
      assert errors_on(changeset)[:email] == ["has invalid format"]
      assert errors_on(changeset)[:password] == ["should be at least 8 character(s)"]
    end

    test "register_user/1 enforces unique emails" do
      assert {:ok, _user} = Accounts.register_user(@valid_user_attrs)
      assert {:error, changeset} = Accounts.register_user(@valid_user_attrs)
      assert errors_on(changeset)[:email] == ["has already been taken"]
    end

    test "authenticate_user/2 returns user on correct credentials, and error on failure" do
      {:ok, user} = Accounts.register_user(@valid_user_attrs)

      assert {:ok, authenticated_user} = Accounts.authenticate_user(user.email, "password123")
      assert authenticated_user.id == user.id

      assert {:error, :unauthorized} = Accounts.authenticate_user(user.email, "wrong_password")

      assert {:error, :unauthorized} =
               Accounts.authenticate_user("nonexistent@example.com", "password123")
    end
  end

  describe "tenants & memberships" do
    setup do
      {:ok, user} = Accounts.register_user(@valid_user_attrs)
      %{user: user}
    end

    test "create_tenant/2 creates a tenant and makes the creator user the owner", %{user: user} do
      assert {:ok, %{tenant: tenant, membership: membership}} =
               Accounts.create_tenant(user, @tenant_attrs)

      assert tenant.name == "ACME Corp"
      assert tenant.slug == "acme-corp"
      assert membership.user_id == user.id
      assert membership.tenant_id == tenant.id
      assert membership.role == "owner"
    end

    test "create_tenant/2 returns error on invalid tenant attributes", %{user: user} do
      invalid_attrs = %{name: "", slug: "ACME CORP IN CAPS"}
      assert {:error, changeset} = Accounts.create_tenant(user, invalid_attrs)
      assert errors_on(changeset)[:name] == ["can't be blank"]
      assert errors_on(changeset)[:slug] == ["has invalid format"]
    end

    test "list_tenants_by_user/1 lists all tenants the user belongs to", %{user: user} do
      assert Accounts.list_tenants_by_user(user) == []

      {:ok, %{tenant: tenant1}} = Accounts.create_tenant(user, @tenant_attrs)

      {:ok, %{tenant: tenant2}} =
        Accounts.create_tenant(user, %{name: "Org Two", slug: "org-two"})

      tenants = Accounts.list_tenants_by_user(user)
      assert length(tenants) == 2
      assert Enum.any?(tenants, fn t -> t.id == tenant1.id end)
      assert Enum.any?(tenants, fn t -> t.id == tenant2.id end)
    end
  end

  describe "membership invitations and edits" do
    setup do
      {:ok, owner} = Accounts.register_user(@valid_user_attrs)

      {:ok, other_user} =
        Accounts.register_user(%{email: "member@example.com", password: "password123"})

      {:ok, %{tenant: tenant}} = Accounts.create_tenant(owner, @tenant_attrs)

      %{owner: owner, other_user: other_user, tenant: tenant}
    end

    test "invite_member/3 links user to tenant with designated role", %{
      tenant: tenant,
      other_user: other_user
    } do
      assert {:ok, %Membership{} = membership} =
               Accounts.invite_member(tenant, other_user.email, "editor")

      assert membership.user_id == other_user.id
      assert membership.tenant_id == tenant.id
      assert membership.role == "editor"
    end

    test "invite_member/3 returns error if user does not exist", %{tenant: tenant} do
      assert {:error, :user_not_found} =
               Accounts.invite_member(tenant, "nonexistent@example.com", "viewer")
    end

    test "update_member_role/3 updates member role", %{tenant: tenant, other_user: other_user} do
      {:ok, _membership} = Accounts.invite_member(tenant, other_user.email, "viewer")
      assert {:ok, updated} = Accounts.update_member_role(tenant, other_user.id, "admin")
      assert updated.role == "admin"
    end

    test "remove_member/2 deletes member from tenant, but prevents owner removal", %{
      tenant: tenant,
      owner: owner,
      other_user: other_user
    } do
      {:ok, _membership} = Accounts.invite_member(tenant, other_user.email, "viewer")
      assert {:ok, _deleted} = Accounts.remove_member(tenant, other_user.id)
      assert Accounts.get_membership(tenant.id, other_user.id) == nil

      # Attempt to remove owner fails
      assert {:error, :cannot_remove_owner} = Accounts.remove_member(tenant, owner.id)
    end
  end
end
