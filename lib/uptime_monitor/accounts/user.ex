defmodule UptimeMonitor.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias UptimeMonitor.Accounts.Membership

  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          email: String.t() | nil,
          password_hash: String.t() | nil,
          is_active: boolean() | nil,
          memberships: [Membership.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "users" do
    field :email, :string
    field :password_hash, :string
    field :is_active, :boolean, default: true
    field :password, :string, virtual: true

    has_many :memberships, Membership

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for registration.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = user, attrs) do
    user
    |> cast(attrs, [:email, :password, :is_active])
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:password, min: 8)
    |> unique_constraint(:email)
    |> hash_password()
  end

  @doc """
  Verifies if a password matches the hashed password.
  """
  @spec valid_password?(t(), String.t()) :: boolean()
  def valid_password?(%__MODULE__{password_hash: password_hash}, password)
      when is_binary(password_hash) do
    case String.split(password_hash, "$") do
      [iterations_str, salt_b64, hash_b64] ->
        iterations = String.to_integer(iterations_str)
        salt = Base.decode64!(salt_b64)
        hash = Base.decode64!(hash_b64)
        computed_hash = :crypto.pbkdf2_hmac(:sha256, password, salt, iterations, 32)
        Plug.Crypto.secure_compare(computed_hash, hash)

      _ ->
        false
    end
  end

  def valid_password?(_, _), do: false

  # Hashing pipeline step
  defp hash_password(changeset) do
    password = get_change(changeset, :password)

    if password && changeset.valid? do
      salt = :crypto.strong_rand_bytes(16)
      iterations = 100_000
      hash = :crypto.pbkdf2_hmac(:sha256, password, salt, iterations, 32)
      hash_str = "#{iterations}$#{Base.encode64(salt)}$#{Base.encode64(hash)}"

      put_change(changeset, :password_hash, hash_str)
    else
      changeset
    end
  end
end
