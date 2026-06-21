# Elixir Module Template & Coding Guidelines

This document outlines the standard structure, naming conventions, and documentation guidelines for all Elixir modules in the `UptimeMonitor` codebase.

---

## 1. Directory Structure and Naming
*   **Namespace Matching**: The module namespace must exactly match its filepath.
    *   File `lib/uptime_monitor/monitors/engine.ex` must define `UptimeMonitor.Monitors.Engine`.
*   **Singular vs. Plural**: Context modules are plural (e.g., `UptimeMonitor.Monitors`), while schema modules and specialized workers are singular (e.g., `UptimeMonitor.Monitors.Monitor`, `UptimeMonitor.Monitors.Worker`).
*   **Nesting Limit**: Do not nest multiple modules in the same file. It causes cyclic dependencies and increases compilation times.

---

## 2. Module Structure Order
To maintain consistency across the codebase, modules should organize their directives and functions in the following order:

1.  **Module Directives**: `use`, `import`, `alias`, `require` (sorted alphabetically within each group).
2.  **Module Documentation**: `@moduledoc` (must contain a high-level explanation of the module's responsibility).
3.  **Module Types**: `@type`, `@opaque`, `@typep` (defining custom domain structures).
4.  **Public API Functions**: Grouped logically, documented with `@doc`, and specified with `@spec`.
5.  **OTP Callbacks**: If the module implements a behavior (e.g., `GenServer`, `Plug`), place them below the public API and tag them with `@impl true`.
6.  **Private Functions**: Helper functions, starting with `defp`. Keep them short, focused, and free of side effects when possible.

---

## 3. Code Template Example

Use this skeletal structure as a starting point for creating new modules:

```elixir
defmodule UptimeMonitor.Context.ModuleName do
  @moduledoc """
  Brief description of what this module does.

  Provide usage examples, details about internal processes (e.g. GenServer state),
  or architectural context if necessary.
  """

  # 1. Directives
  use GenServer # or other behaviours

  import Ecto.Query, only: [from: 2]
  
  alias UptimeMonitor.Repo
  alias UptimeMonitor.Accounts.User

  # 2. Module Attributes / Constants
  @default_timeout :timer.seconds(5)

  # 3. Typespecs
  @type option :: {:timeout, timeout()} | {:retry, boolean()}
  @type result :: {:ok, map()} | {:error, term()}

  # 4. Public API
  
  @doc """
  Performs a specific business action.

  ## Parameters
    - `user`: The %User{} struct triggering the action.
    - `params`: A map of parameters.
    - `opts`: A keyword list of optional parameters.

  ## Examples

      iex> UptimeMonitor.Context.ModuleName.perform_action(user, %{field: "val"})
      {:ok, %{result: "success"}}

  """
  @spec perform_action(User.t(), map(), [option()]) :: result()
  def perform_action(%User{} = user, params, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    
    # Implementation using functional pipe composition
    user
    | |> do_prepare_data(params)
    | |> execute_with_timeout(timeout)
  end

  # 5. Callback Implementations (if any)
  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  # 6. Private Helpers
  
  defp do_prepare_data(%User{id: id}, params) do
    Map.put(params, :user_id, id)
  end

  defp execute_with_timeout(data, timeout) do
    # Business logic goes here
    {:ok, data}
  end
end
```

---

## 4. Predicates and Naming Rules
*   **Predicates**: Functions that return a boolean must end with a question mark `?` (e.g., `active?`, `authorized?`).
*   **Guards vs Predicates**: Reserve the `is_` prefix strictly for custom guard definitions (e.g., `defguard is_active(user)`). Normal predicate functions should not start with `is_`.
*   **Variables Rebinding**: Never rebind variables inside conditional blocks like `if`, `case`, `cond` or `with` if you want to use the updated value outer-scope. Always assign the block's return value:
    ```elixir
    # Correct
    socket =
      if connected?(socket) do
        assign(socket, :val, val)
      else
        socket
      end
    ```
