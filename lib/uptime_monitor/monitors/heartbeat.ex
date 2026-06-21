defmodule UptimeMonitor.Monitors.Heartbeat do
  use Ecto.Schema
  import Ecto.Changeset

  alias UptimeMonitor.Accounts.Tenant

  @type t :: %__MODULE__{
    id: pos_integer() | nil,
    name: String.t() | nil,
    token: String.t() | nil,
    expected_interval_seconds: pos_integer() | nil,
    grace_period_seconds: pos_integer() | nil,
    last_pinged_at: DateTime.t() | nil,
    tenant_id: pos_integer() | nil,
    tenant: Tenant.t() | Ecto.Association.NotLoaded.t(),
    inserted_at: DateTime.t() | nil,
    updated_at: DateTime.t() | nil
  }

  schema "heartbeats" do
    field :name, :string
    field :token, :string
    field :expected_interval_seconds, :integer, default: 86400
    field :grace_period_seconds, :integer, default: 900
    field :last_pinged_at, :utc_datetime

    belongs_to :tenant, Tenant

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for Heartbeat.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = heartbeat, attrs) do
    heartbeat
    |> cast(attrs, [:name, :expected_interval_seconds, :grace_period_seconds, :last_pinged_at])
    |> validate_required([:name])
    |> validate_number(:expected_interval_seconds, greater_than: 0)
    |> validate_number(:grace_period_seconds, greater_than_or_equal_to: 0)
    |> unique_constraint(:token)
    |> generate_token()
  end

  defp generate_token(changeset) do
    if get_field(changeset, :token) do
      changeset
    else
      token = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
      put_change(changeset, :token, token)
    end
  end
end
