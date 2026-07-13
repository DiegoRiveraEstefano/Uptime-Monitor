defmodule UptimeMonitor.Alerts.NotificationChannel do
  use Ecto.Schema
  import Ecto.Changeset

  alias UptimeMonitor.Accounts.Tenant

  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          type: String.t() | nil,
          active: boolean() | nil,
          config: map() | nil,
          tenant_id: pos_integer() | nil,
          tenant: Tenant.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "notification_channels" do
    field :type, :string
    field :active, :boolean, default: true
    field :config, :map, default: %{}

    belongs_to :tenant, Tenant

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for NotificationChannel.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = channel, attrs) do
    channel
    |> cast(attrs, [:type, :active, :config])
    |> validate_required([:type, :active, :config])
    |> validate_inclusion(:type, ["platform", "email", "slack", "webhook"])
    |> validate_config()
  end

  defp validate_config(changeset) do
    type = get_field(changeset, :type)
    config = get_field(changeset, :config)

    if changeset.valid? do
      case type do
        "slack" ->
          case Map.get(config, "webhook_url") do
            url when is_binary(url) ->
              if String.starts_with?(url, "https://hooks.slack.com/") do
                changeset
              else
                add_error(
                  changeset,
                  :config,
                  "must contain a valid Slack webhook URL starting with https://hooks.slack.com/"
                )
              end

            _ ->
              add_error(changeset, :config, "must specify key 'webhook_url'")
          end

        "webhook" ->
          case Map.get(config, "url") do
            url when is_binary(url) ->
              if String.starts_with?(url, "http://") || String.starts_with?(url, "https://") do
                changeset
              else
                add_error(changeset, :config, "must contain a valid HTTP or HTTPS endpoint URL")
              end

            _ ->
              add_error(changeset, :config, "must specify key 'url'")
          end

        "email" ->
          case Map.get(config, "to") do
            email when is_binary(email) ->
              if String.contains?(email, "@") do
                changeset
              else
                add_error(changeset, :config, "must specify a valid target email address")
              end

            _ ->
              add_error(changeset, :config, "must specify key 'to'")
          end

        _ ->
          changeset
      end
    else
      changeset
    end
  end
end
