defmodule UptimeMonitorWeb.CatalogLive do
  @moduledoc """
  Styleguide and component catalog page for UptimeMonitor developers.
  Accessible in development/testing to review, test, and copy visual components.
  """
  use UptimeMonitorWeb, :live_view

  # Import our newly created components
  alias UptimeMonitorWeb.UptimeComponents
  alias UptimeMonitorWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    # Set up dummy form to drive custom_input examples
    dummy_params = %{
      "email" => "dev@uptime.com",
      "target_url" => "https://api.acme.com/v1/health"
    }

    form = Phoenix.Component.to_form(dummy_params, as: :catalog)

    {:ok, assign(socket, form: form)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-12 pb-24">
        <!-- Title and Introduction -->
        <div class="border-b border-slate-100 pb-6">
          <h1 class="text-4xl font-extrabold font-sans text-slate-900 tracking-tight">Component Catalog</h1>
          <p class="text-sm text-slate-500 mt-2">
            Visual library showcasing our minimal light design system (White background + Pastel Purple accents).
          </p>
        </div>

        <!-- 1. Buttons Section -->
        <section class="space-y-4">
          <h2 class="text-2xl font-bold font-sans text-slate-800">Buttons</h2>
          <p class="text-xs text-slate-400">Pastel purple accents, slate borders, and ghost action indicators.</p>
          
          <div class="bg-slate-50 border border-slate-100 rounded-2xl p-6 space-y-6">
            <div class="flex flex-wrap items-center gap-4">
              <UptimeComponents.primary_button>
                <UptimeMonitorWeb.CoreComponents.icon name="hero-plus-micro" class="size-4" />
                Primary Action
              </UptimeComponents.primary_button>

              <UptimeComponents.secondary_button>
                Configure
              </UptimeComponents.secondary_button>

              <UptimeComponents.ghost_button>
                <UptimeMonitorWeb.CoreComponents.icon name="hero-cog-6-tooth" class="size-4" />
                Settings
              </UptimeComponents.ghost_button>
            </div>
            
            <div class="bg-white rounded-xl p-4 border border-slate-100">
              <pre class="text-xs text-slate-600 overflow-x-auto"><code phx-no-curly-interpolation>
                &lt;.primary_button&gt;Action&lt;/.primary_button&gt;
                &lt;.secondary_button&gt;Configure&lt;/.secondary_button&gt;
                &lt;.ghost_button&gt;Settings&lt;/.ghost_button&gt;
              </code></pre>
            </div>
          </div>
        </section>

        <!-- 2. Badges Section -->
        <section class="space-y-4">
          <h2 class="text-2xl font-bold font-sans text-slate-800">Status Badges</h2>
          <p class="text-xs text-slate-400">Pills to represent health checks states. DOWN state utilizes a soft breathing pulse.</p>
          
          <div class="bg-slate-50 border border-slate-100 rounded-2xl p-6 space-y-6">
            <div class="flex flex-wrap gap-4">
              <UptimeComponents.status_badge status="up" />
              <UptimeComponents.status_badge status="warning" />
              <UptimeComponents.status_badge status="down" />
              <UptimeComponents.status_badge status="pending" />
            </div>

            <div class="bg-white rounded-xl p-4 border border-slate-100">
              <pre class="text-xs text-slate-600 overflow-x-auto"><code phx-no-curly-interpolation>
                &lt;.status_badge status="up" /&gt;
                &lt;.status_badge status="warning" /&gt;
                &lt;.status_badge status="down" /&gt;
                &lt;.status_badge status="pending" /&gt;
              </code></pre>
            </div>
          </div>
        </section>

        <!-- 3. Form Inputs -->
        <section class="space-y-4">
          <h2 class="text-2xl font-bold font-sans text-slate-800">Form Inputs</h2>
          <p class="text-xs text-slate-400">Clean input boxes with custom padding, borders, and focused purple outline highlights.</p>
          
          <div class="bg-slate-50 border border-slate-100 rounded-2xl p-6 space-y-6">
            <div class="max-w-md bg-white p-6 rounded-xl border border-slate-100">
              <UptimeComponents.custom_input
                field={@form[:email]}
                label="Organization Owner Email"
                placeholder="email@example.com"
              />

              <UptimeComponents.custom_input
                field={@form[:target_url]}
                label="Monitoring URL"
                placeholder="https://"
              />
            </div>

            <div class="bg-white rounded-xl p-4 border border-slate-100">
              <pre class="text-xs text-slate-600 overflow-x-auto"><code phx-no-curly-interpolation>&lt;.custom_input field={@form[:email]} label="Owner Email" /&gt;</code></pre>
            </div>
          </div>
        </section>

        <!-- 4. Metric & KPI Cards -->
        <section class="space-y-4">
          <h2 class="text-2xl font-bold font-sans text-slate-800">Metrics Cards</h2>
          <p class="text-xs text-slate-400">Cards for summarizing SLA percentages and health latency aggregates.</p>
          
          <div class="bg-slate-50 border border-slate-100 rounded-2xl p-6 space-y-6">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <UptimeComponents.metric_card
                title="Global Uptime SLA"
                value="99.98%"
                change="+0.04%"
                trend="up"
              />

              <UptimeComponents.metric_card
                title="Active Outages"
                value="2"
                change="-1 resolved"
                trend="down"
              />
            </div>

            <div class="bg-white rounded-xl p-4 border border-slate-100">
              <pre class="text-xs text-slate-600 overflow-x-auto"><code phx-no-curly-interpolation>&lt;.metric_card title="Global SLA" value="99.9%" change="+0.04%" trend="up" /&gt;</code></pre>
            </div>
          </div>
        </section>

        <!-- 5. Monitor Cards -->
        <section class="space-y-4">
          <h2 class="text-2xl font-bold font-sans text-slate-800">Monitor Cards</h2>
          <p class="text-xs text-slate-400">Target monitor detail block demonstrating statuses and aggregate metrics.</p>
          
          <div class="bg-slate-50 border border-slate-100 rounded-2xl p-6 space-y-6">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <UptimeComponents.monitor_card
                name="Payment Webhook API"
                url="https://api.stripe.com/v3/charge"
                status="up"
                uptime={99.94}
                latency={112.5}
              />

              <UptimeComponents.monitor_card
                name="Auth Gateway Server"
                url="https://auth.acme.com/oauth/token"
                status="down"
                uptime={92.1}
                latency={4520.0}
              />
            </div>

            <div class="bg-white rounded-xl p-4 border border-slate-100">
              <pre class="text-xs text-slate-600 overflow-x-auto"><code phx-no-curly-interpolation>&lt;.monitor_card name="Stripe Check" url="https://api.com" status="up" uptime={99.9} latency={120} /&gt;</code></pre>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
