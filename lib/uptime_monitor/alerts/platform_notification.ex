defmodule UptimeMonitor.Alerts.PlatformNotification do
  use Ecto.Schema
  import Ecto.Changeset

  alias UptimeMonitor.Accounts.Tenant

  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          title: String.t() | nil,
          message: String.t() | nil,
          read: boolean() | nil,
          tenant_id: pos_integer() | nil,
          tenant: Tenant.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "platform_notifications" do
    field :title, :string
    field :message, :string
    field :read, :boolean, default: false

    belongs_to :tenant, Tenant

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for PlatformNotification.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = notification, attrs) do
    notification
    |> cast(attrs, [:title, :message, :read])
    |> validate_required([:title, :message])
  end
end
