defmodule UptimeMonitor.Incidents.Incident do
  use Ecto.Schema
  import Ecto.Changeset

  alias UptimeMonitor.Accounts.Tenant
  alias UptimeMonitor.Monitors.Monitor
  alias UptimeMonitor.Incidents.PostMortem

  @type t :: %__MODULE__{
    id: pos_integer() | nil,
    status: String.t() | nil,
    opened_at: DateTime.t() | nil,
    resolved_at: DateTime.t() | nil,
    downtime_seconds: integer() | nil,
    monitor_id: pos_integer() | nil,
    monitor: Monitor.t() | Ecto.Association.NotLoaded.t(),
    tenant_id: pos_integer() | nil,
    tenant: Tenant.t() | Ecto.Association.NotLoaded.t(),
    post_mortem: PostMortem.t() | Ecto.Association.NotLoaded.t(),
    inserted_at: DateTime.t() | nil,
    updated_at: DateTime.t() | nil
  }

  schema "incidents" do
    field :status, :string, default: "open"
    field :opened_at, :utc_datetime
    field :resolved_at, :utc_datetime
    field :downtime_seconds, :integer

    belongs_to :tenant, Tenant
    belongs_to :monitor, Monitor
    has_one :post_mortem, PostMortem

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for Incident.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = incident, attrs) do
    incident
    |> cast(attrs, [:status, :opened_at, :resolved_at, :downtime_seconds])
    |> validate_required([:status, :opened_at])
    |> validate_inclusion(:status, ["open", "resolved"])
  end
end
