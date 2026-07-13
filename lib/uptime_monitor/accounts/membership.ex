defmodule UptimeMonitor.Accounts.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  alias UptimeMonitor.Accounts.{User, Tenant}

  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          role: String.t() | nil,
          user_id: pos_integer() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          tenant_id: pos_integer() | nil,
          tenant: Tenant.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "memberships" do
    field :role, :string

    belongs_to :user, User
    belongs_to :tenant, Tenant

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for Membership.
  Note that user_id and tenant_id are not cast here to avoid parameters injection.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = membership, attrs) do
    membership
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_inclusion(:role, ["owner", "admin", "editor", "viewer"])
    |> unique_constraint([:tenant_id, :user_id], name: :memberships_tenant_id_user_id_index)
  end
end
