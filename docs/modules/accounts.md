# Accounts Domain Module Details

This document details the specifications, schemas, functions, and middleware plugs for the `UptimeMonitor.Accounts` domain.

---

## 1. Context: `UptimeMonitor.Accounts`
The primary interface for accounts operations. It handles database transactions for user registrations, tenant setups, and membership operations.

### Public API Specifications
*   `register_user(attrs)`:
    *   **Input**: A map of user attributes.
    *   **Output**: `{:ok, %User{}}` | `{:error, Ecto.Changeset.t()}`
*   `create_tenant(user, tenant_attrs)`:
    *   **Input**: A `%User{}` and a map of tenant attributes.
    *   **Behavior**: Executes a transaction via `Ecto.Multi`. Inserts the tenant, and creates a membership mapping the user as the `"owner"` role.
    *   **Output**: `{:ok, %{tenant: %Tenant{}, membership: %Membership{}}}` | `{:error, failed_step, reason, changes}`
*   `invite_member(tenant, email, role)`:
    *   **Input**: A `%Tenant{}`, email string, and role string (e.g., `"admin"`, `"editor"`, `"viewer"`).
    *   **Behavior**: Verifies if the email matches an existing user. If yes, inserts a `Membership` record. If no, plans future implementation for pending email invitations.
    *   **Output**: `{:ok, %Membership{}}` | `{:error, term()}`

---

## 2. Schema: `UptimeMonitor.Accounts.User`
Represents authentication and identity.

### Fields and Schema
*   `email` (`:string`, null: false, unique)
*   `password_hash` (`:string`, null: false)
*   `is_active` (`:boolean`, default: true)
*   `memberships` (`has_many` `UptimeMonitor.Accounts.Membership`)

### Changeset Validations
*   Validates format of `email` (using regex verification).
*   Enforces password strength (minimum 8 characters).
*   Hashes password using `Bcrypt` before storage (stored in `password_hash`).

---

## 3. Schema: `UptimeMonitor.Accounts.Tenant`
Represents an organization (customer tenant).

### Fields and Schema
*   `name` (`:string`, null: false)
*   `slug` (`:string`, null: false, unique) - Lowercase string with hyphens.
*   `memberships` (`has_many` `UptimeMonitor.Accounts.Membership`)

### Changeset Validations
*   Validates format of `slug` (alphanumeric and hyphens only).
*   Enforces slug uniqueness at database index level.

---

## 4. Schema: `UptimeMonitor.Accounts.Membership`
A join table associating users with organizations, assigning their access role.

### Fields and Schema
*   `user_id` (`belongs_to` `User`, null: false)
*   `tenant_id` (`belongs_to` `Tenant`, null: false)
*   `role` (`:string`, null: false) - Enforces role enums: `"owner"`, `"admin"`, `"editor"`, `"viewer"`.

### Changeset Validations
*   Enforces valid role strings.
*   Ensures unique constraint on `[:user_id, :tenant_id]` to prevent duplicate memberships.

---

## 5. Web Plugs

### `UptimeMonitorWeb.Plugs.RequireTenant`
A Plug module checking that requests are scoped to a valid tenant.
*   **Behavior**: Inspects path parameters (e.g., `/org/:tenant_slug`) or cookies. Looks up the tenant by slug in the database.
*   **Success**: Assigns `:current_tenant` to `conn.assigns` and fetches the user's role membership for that tenant, assigning `:current_role`.
*   **Failure**: Halts connection, returns `404 Not Found` or redirects to organization picker.

### `UptimeMonitorWeb.Plugs.RequireRole`
A middleware plug checking role privileges.
*   **Behavior**: Configured with a minimum role privilege level (e.g., `plug RequireRole, min_role: :editor`).
*   **Success**: Passes connection forward if `conn.assigns.current_role` is equal or higher than the target parameter.
*   **Failure**: Halts connection, registers error in LiveView/Controller flash, and redirects to unauthorized page.
