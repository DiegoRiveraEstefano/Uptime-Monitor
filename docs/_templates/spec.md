# Elixir Typespecs & Dialyzer Guidelines

Writing explicit type specifications using Elixir's `@spec` and `@type` attributes helps ensure static correctness via **Dialyzer**, serves as living documentation, and helps identify domain model inconsistencies early.

---

## 1. Core Guidelines

*   **Specify All Public API Functions**: Every public function (`def`) must be accompanied by a `@spec`. Private functions (`defp`) may use specs if they contain complex logic or help clarify type transitions.
*   **Leverage Custom Domain Types**: Define semantic type names using `@type` for data structures that are reused across different modules (e.g., representation of coordinates, request headers, error models).
*   **Enforce Schema Types**: Every Ecto schema should define a `t()` type (e.g., `@type t :: %__MODULE__{...}`).
*   **Avoid Generic Types**: Use specific types like `pos_integer()` or `non_neg_integer()` instead of just `integer()`, and define key-value structures when using maps if possible.

---

## 2. Standard Types Quick Reference

| Type | Syntax | Description |
| :--- | :--- | :--- |
| **String** | `String.t()` | Correct type for text (binary in Elixir). Do not use `string()`. |
| **Boolean** | `boolean()` | `true` or `false`. |
| **Integer** | `integer()`, `pos_integer()`, `non_neg_integer()` | Numerical values (positive, zero/positive, etc.). |
| **Atom** | `atom()` | Atoms, e.g. `:ok`, `:error`. |
| **List** | `list(element_type)` or `[element_type]` | List containing elements of `element_type`. |
| **Map** | `%{required(key_type) => value_type}` | Map with typed keys and values. |
| **Struct** | `%ModuleName{}` or `ModuleName.t()` | Instance of a specific struct/schema. |

---

## 3. Template Code Example

Here is an example showing how custom types, opaque types, and specs are declared:

```elixir
defmodule UptimeMonitor.Alerts.Notifier do
  @moduledoc """
  Coordinates notifications when monitor statuses transition.
  """

  alias UptimeMonitor.Monitors.Monitor

  # 1. Custom Types
  @type channel :: :email | :slack | :webhook
  @type alert_status :: :up | :down
  
  @type payload :: %{
    required(:event) => alert_status(),
    required(:monitor_id) => pos_integer(),
    required(:url) => String.t(),
    required(:latency_ms) => non_neg_integer(),
    optional(:error_reason) => String.t()
  }

  @type response :: {:ok, message_id :: String.t()} | {:error, reason :: term()}

  # 2. Opaque Types (internal structure is hidden from other modules)
  @opaque client :: %{
    client_id: String.t(),
    token: String.t(),
    expires_at: DateTime.t()
  }

  # 3. Public Specifications
  
  @doc """
  Initializes a notifier client config.
  """
  @spec init_client(String.t(), String.t()) :: {:ok, client()} | {:error, :expired}
  def init_client(client_id, token) do
    # Internal logic returning client
    {:ok, %{client_id: client_id, token: token, expires_at: DateTime.utc_now()}}
  end

  @doc """
  Dispatches an alert to a specific channel.
  """
  @spec dispatch(channel(), Monitor.t(), alert_status(), [client_id: String.t()]) :: response()
  def dispatch(:email, %Monitor{} = monitor, event, opts) do
    client_id = Keyword.get(opts, :client_id, "default")
    # Dispatch via Swoosh Mailer
    {:ok, "email_job_#{monitor.id}_#{event}"}
  end

  def dispatch(:slack, %Monitor{} = monitor, event, _opts) do
    # Dispatch via Req Webhook
    {:ok, "slack_ts_#{monitor.id}_#{event}"}
  end

  def dispatch(channel, _monitor, _event, _opts) do
    {:error, {:invalid_channel, channel}}
  end
end
```

---

## 4. Troubleshooting Dialyzer Failures
*   **"Success Typings"**: Dialyzer works by finding contradictions (i.e. where code *must* fail), not by proving safety. If Dialyzer points to a mismatch, trust it; it means code path will unconditionally crash at runtime.
*   **Nil Checks**: Ensure you allow `nil` in types where data can be optional or empty (e.g. `String.t() | nil`).
*   **Ecto Associations**: Unloaded associations evaluate to `%Ecto.Association.NotLoaded{}` at runtime. If you specify `AssociationName.t()`, ensure you preloaded it or set the type to `AssociationName.t() | Ecto.Association.NotLoaded.t()`.
