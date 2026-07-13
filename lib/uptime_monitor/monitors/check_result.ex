defmodule UptimeMonitor.Monitors.CheckResult do
  use Ecto.Schema
  import Ecto.Changeset

  alias UptimeMonitor.Monitors.Monitor

  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          status: String.t() | nil,
          latency_ms: pos_integer() | nil,
          response_code: integer() | nil,
          debug_response_body: String.t() | nil,
          monitor_id: pos_integer() | nil,
          monitor: Monitor.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "check_results" do
    field :status, :string
    field :latency_ms, :integer
    field :response_code, :integer
    field :debug_response_body, :string

    belongs_to :monitor, Monitor

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for CheckResult.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = check_result, attrs) do
    check_result
    |> cast(attrs, [:status, :latency_ms, :response_code, :debug_response_body])
    |> validate_required([:status, :latency_ms])
    |> validate_inclusion(:status, ["up", "down"])
    |> validate_number(:latency_ms, greater_than_or_equal_to: 0)
    |> truncate_debug_body()
  end

  defp truncate_debug_body(changeset) do
    case get_change(changeset, :debug_response_body) do
      nil ->
        changeset

      body when is_binary(body) ->
        truncated = String.slice(body, 0, 2048)
        put_change(changeset, :debug_response_body, truncated)
    end
  end
end
