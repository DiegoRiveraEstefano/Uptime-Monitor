defmodule UptimeMonitorWeb.UptimeComponents do
  @moduledoc """
  Custom visual components for UptimeMonitor.
  Implements the minimalist design system: pure white canvas, soft slate borders,
  and pastel purple highlights.
  """
  use Phoenix.Component

  # Access Phoenix router tags for verified routes
  import UptimeMonitorWeb.CoreComponents, only: [icon: 1]

  # --- Button Components ---

  @doc """
  Renders a primary button with a pastel purple background and hover states.
  """
  attr :type, :string, default: "button", values: ~w(button submit reset)
  attr :disabled, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  def primary_button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class="bg-[hsl(268,80%,75%)] text-[hsl(268,50%,30%)] hover:bg-[hsl(268,65%,68%)] active:scale-98 transition-all duration-200 ease-in-out font-semibold px-5 py-2.5 rounded-xl shadow-sm hover:shadow-md disabled:opacity-50 disabled:pointer-events-none cursor-pointer flex items-center justify-center gap-2 text-sm"
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders a secondary button with a border and subtle hover state.
  """
  attr :type, :string, default: "button", values: ~w(button submit reset)
  attr :disabled, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  def secondary_button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class="bg-white text-slate-700 border border-slate-100 hover:bg-slate-50 active:scale-98 transition-all duration-200 ease-in-out font-medium px-5 py-2.5 rounded-xl shadow-sm disabled:opacity-50 disabled:pointer-events-none cursor-pointer flex items-center justify-center gap-2 text-sm"
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders a ghost button for secondary actions.
  """
  attr :type, :string, default: "button", values: ~w(button submit reset)
  attr :disabled, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  def ghost_button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class="bg-transparent text-slate-500 hover:text-slate-900 hover:bg-slate-50 transition-all duration-150 ease-in-out font-medium px-4 py-2.5 rounded-lg disabled:opacity-50 disabled:pointer-events-none cursor-pointer flex items-center justify-center gap-1.5 text-sm"
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  # --- Status Badges ---

  @doc """
  Renders a status pill for monitor health.
  """
  attr :status, :string, required: true, values: ~w(up warning down pending)

  def status_badge(assigns) do
    ~H"""
    <span class={[
      "px-3 py-1 rounded-full text-xs font-semibold inline-flex items-center gap-1.5 border",
      @status == "up" && "bg-emerald-50 text-emerald-700 border-emerald-100",
      @status == "down" && "bg-rose-50 text-rose-700 border-rose-100 animate-pulse",
      @status == "warning" && "bg-amber-50 text-amber-700 border-amber-100",
      @status == "pending" && "bg-slate-50 text-slate-600 border-slate-100"
    ]}>
      <span class={[
        "size-2 rounded-full",
        @status == "up" && "bg-emerald-500",
        @status == "down" && "bg-rose-500",
        @status == "warning" && "bg-amber-500",
        @status == "pending" && "bg-slate-400"
      ]} />
      {String.upcase(@status)}
    </span>
    """
  end

  # --- Input Form Fields ---

  @doc """
  Custom clean text/password inputs that override browser defaults.
  """
  attr :label, :string, default: nil
  attr :field, :any, doc: "The FormField struct"
  attr :type, :string, default: "text"
  attr :placeholder, :string, default: nil
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :rest, :global

  def custom_input(assigns) do
    ~H"""
    <div class="mb-4">
      <label :if={@label} class="block text-xs font-semibold uppercase tracking-wider text-slate-500 mb-1.5">
        {@label}
      </label>
      <input
        type={@type}
        name={@field.name}
        id={@field.id}
        value={@field.value}
        placeholder={@placeholder}
        disabled={@disabled}
        class="w-full bg-white text-slate-900 border border-slate-100 focus:border-[hsl(268,80%)] focus:ring-1 focus:ring-[hsl(268,80%)] outline-none rounded-xl px-4 py-2.5 text-sm transition-all duration-150 disabled:bg-slate-50 disabled:text-slate-400"
        {@rest}
      />
      <.error :for={err <- @field.errors} message={err} />
    </div>
    """
  end

  defp error(assigns) do
    ~H"""
    <p class="text-xs text-rose-600 mt-1.5 flex items-center gap-1">
      <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
      {translate_error(@message)}
    </p>
    """
  end

  # --- Cards & UI Containers ---

  @doc """
  Uptime Monitor detail card. Displays target parameters and stats.
  """
  attr :name, :string, required: true
  attr :url, :string, required: true
  attr :status, :string, required: true
  attr :uptime, :float, required: true
  attr :latency, :float, required: true

  def monitor_card(assigns) do
    ~H"""
    <div class="bg-white border border-slate-100 rounded-2xl p-6 shadow-sm hover:shadow-md transition-all duration-200">
      <div class="flex items-start justify-between gap-4 mb-4">
        <div>
          <h4 class="font-bold text-lg text-slate-900 font-sans tracking-tight">{@name}</h4>
          <a href={@url} target="_blank" class="text-xs text-slate-400 hover:text-[hsl(268,60%)] transition-colors flex items-center gap-1 mt-1">
            {@url}
            <.icon name="hero-arrow-top-right-on-square" class="size-3" />
          </a>
        </div>
        <.status_badge status={@status} />
      </div>

      <div class="grid grid-cols-2 gap-4 border-t border-slate-50 pt-4 mt-2">
        <div>
          <span class="block text-[10px] uppercase font-semibold text-slate-400 tracking-wider">Uptime (30d)</span>
          <span class="text-base font-bold text-slate-800">{@uptime}%</span>
        </div>
        <div>
          <span class="block text-[10px] uppercase font-semibold text-slate-400 tracking-wider">Avg Latency</span>
          <span class="text-base font-bold text-slate-800">{@latency}ms</span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  A KPI metric block.
  """
  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :change, :string, default: nil
  attr :trend, :string, default: nil, values: ["up", "down", "neutral", nil]

  def metric_card(assigns) do
    ~H"""
    <div class="bg-white border border-slate-100 rounded-2xl p-6 shadow-sm">
      <span class="block text-xs uppercase font-semibold text-slate-500 tracking-wider mb-2">{@title}</span>
      <div class="flex items-baseline gap-2">
        <span class="text-3xl font-extrabold text-slate-900 font-sans tracking-tight">{@value}</span>
        <span :if={@change} class={[
          "text-xs font-semibold px-2 py-0.5 rounded-full inline-flex items-center gap-0.5",
          @trend == "up" && "bg-emerald-50 text-emerald-700",
          @trend == "down" && "bg-rose-50 text-rose-700",
          @trend == "neutral" && "bg-slate-50 text-slate-600"
        ]}>
          <.icon :if={@trend == "up"} name="hero-arrow-trending-up" class="size-3" />
          <.icon :if={@trend == "down"} name="hero-arrow-trending-down" class="size-3" />
          {@change}
        </span>
      </div>
    </div>
    """
  end

  # Helper translating errors
  defp translate_error({msg, opts}) do
    # Simple gettext error translator
    if count = opts[:count] do
      Gettext.dngettext(UptimeMonitorWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(UptimeMonitorWeb.Gettext, "errors", msg, opts)
    end
  end
end
