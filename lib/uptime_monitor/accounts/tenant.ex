defmodule UptimeMonitor.Accounts.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  alias UptimeMonitor.Accounts.Membership

  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          name: String.t() | nil,
          slug: String.t() | nil,
          memberships: [Membership.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "tenants" do
    field :name, :string
    field :slug, :string

    has_many :memberships, Membership

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for Tenant.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name, :slug])
    |> validate_format(:slug, ~r/^[a-z0-9\-]+$/)
    |> unique_constraint(:slug)
  end
end
