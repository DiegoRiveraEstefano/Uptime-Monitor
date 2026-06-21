defmodule UptimeMonitor.Metrics.DailyRollup do
  use Ecto.Schema
  import Ecto.Changeset

  alias UptimeMonitor.Monitors.Monitor

  @type t :: %__MODULE__{
    id: pos_integer() | nil,
    date: Date.t() | nil,
    total_checks: pos_integer() | nil,
    failed_checks: pos_integer() | nil,
    total_latency_ms: pos_integer() | nil,
    monitor_id: pos_integer() | nil,
    monitor: Monitor.t() | Ecto.Association.NotLoaded.t(),
    inserted_at: DateTime.t() | nil,
    updated_at: DateTime.t() | nil
  }

  schema "daily_rollups" do
    field :date, :date
    field :total_checks, :integer
    field :failed_checks, :integer
    field :total_latency_ms, :integer

    belongs_to :monitor, Monitor

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for DailyRollup.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = rollup, attrs) do
    rollup
    |> cast(attrs, [:date, :total_checks, :failed_checks, :total_latency_ms, :monitor_id])
    |> validate_required([:date, :total_checks, :failed_checks, :total_latency_ms, :monitor_id])
    |> validate_number(:total_checks, greater_than_or_equal_to: 0)
    |> validate_number(:failed_checks, greater_than_or_equal_to: 0)
    |> validate_number(:total_latency_ms, greater_than_or_equal_to: 0)
    |> unique_constraint([:monitor_id, :date], name: :daily_rollups_monitor_id_date_index)
  end
end
