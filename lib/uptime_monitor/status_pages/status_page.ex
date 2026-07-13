defmodule UptimeMonitor.StatusPages.StatusPage do
  use Ecto.Schema
  import Ecto.Changeset

  alias UptimeMonitor.Accounts.Tenant

  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          title: String.t() | nil,
          slug: String.t() | nil,
          is_public: boolean() | nil,
          visible_monitor_ids: [pos_integer()] | nil,
          tenant_id: pos_integer() | nil,
          tenant: Tenant.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "status_pages" do
    field :title, :string
    field :slug, :string
    field :is_public, :boolean, default: true
    field :visible_monitor_ids, {:array, :integer}, default: []

    belongs_to :tenant, Tenant

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for StatusPage.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = status_page, attrs) do
    status_page
    |> cast(attrs, [:title, :slug, :is_public, :visible_monitor_ids])
    |> validate_required([:title, :slug])
    |> validate_format(:slug, ~r/^[a-z0-9\-]+$/)
    |> unique_constraint(:slug)
  end
end
