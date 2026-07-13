defmodule UptimeMonitor.Monitors.Monitor do
  use Ecto.Schema
  import Ecto.Changeset

  alias UptimeMonitor.Accounts.Tenant
  alias UptimeMonitor.Monitors.CheckResult

  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          name: String.t() | nil,
          url: String.t() | nil,
          interval_seconds: pos_integer() | nil,
          active: boolean() | nil,
          encrypted_headers: map() | nil,
          tenant_id: pos_integer() | nil,
          tenant: Tenant.t() | Ecto.Association.NotLoaded.t(),
          check_results: [CheckResult.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "monitors" do
    field :name, :string
    field :url, :string
    field :interval_seconds, :integer, default: 60
    field :active, :boolean, default: true
    field :encrypted_headers, :map, default: %{}

    belongs_to :tenant, Tenant
    has_many :check_results, CheckResult

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for Monitor.
  Note: tenant_id is explicitly set programmatically inside context functions to avoid mass-assignment vulnerabilities.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = monitor, attrs) do
    monitor
    |> cast(attrs, [:name, :url, :interval_seconds, :active, :encrypted_headers])
    |> validate_required([:name, :url])
    |> validate_number(:interval_seconds, greater_than_or_equal_to: 30)
    |> validate_url(:url)
    |> unique_constraint([:tenant_id, :url], name: :monitors_tenant_id_url_index)
  end

  @doc """
  Changeset to pause or resume a monitor.
  """
  @spec active_changeset(t(), boolean()) :: Ecto.Changeset.t()
  def active_changeset(%__MODULE__{} = monitor, active) do
    change(monitor, active: active)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _field, url ->
      case URI.new(url) do
        {:ok, %URI{scheme: scheme, host: host}}
        when scheme in ["http", "https"] and not is_nil(host) ->
          []

        _ ->
          [{field, "must be a valid HTTP or HTTPS URL"}]
      end
    end)
  end
end
