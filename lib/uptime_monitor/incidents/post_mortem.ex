defmodule UptimeMonitor.Incidents.PostMortem do
  use Ecto.Schema
  import Ecto.Changeset

  alias UptimeMonitor.Incidents.Incident
  alias UptimeMonitor.Accounts.User

  @type t :: %__MODULE__{
    id: pos_integer() | nil,
    title: String.t() | nil,
    content: String.t() | nil,
    incident_id: pos_integer() | nil,
    incident: Incident.t() | Ecto.Association.NotLoaded.t(),
    created_by_id: pos_integer() | nil,
    created_by: User.t() | Ecto.Association.NotLoaded.t(),
    inserted_at: DateTime.t() | nil,
    updated_at: DateTime.t() | nil
  }

  schema "post_mortems" do
    field :title, :string
    field :content, :string # Must use :string even for database text/markdown columns

    belongs_to :incident, Incident
    belongs_to :created_by, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for PostMortem.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = post_mortem, attrs) do
    post_mortem
    |> cast(attrs, [:title, :content])
    |> validate_required([:title, :content])
    |> validate_length(:title, min: 5, max: 255)
    |> validate_length(:content, min: 20)
    |> unique_constraint(:incident_id)
  end
end
