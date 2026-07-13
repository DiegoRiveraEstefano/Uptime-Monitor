defmodule UptimeMonitorWeb.RegisterLive do
  @moduledoc """
  Registration interface for UptimeMonitor.
  """
  use UptimeMonitorWeb, :live_view

  alias UptimeMonitorWeb.UptimeComponents
  alias UptimeMonitorWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    form = Phoenix.Component.to_form(%{"email" => "", "password" => ""}, as: :register)
    {:ok, assign(socket, form: form)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-md mx-auto bg-white border border-slate-100 rounded-3xl p-8 shadow-sm space-y-6 mt-12">
        <div class="text-center space-y-2">
          <h2 class="text-3xl font-extrabold font-sans text-slate-900 tracking-tight">
            Create Account
          </h2>
          <p class="text-sm text-slate-500">Start monitoring your services in seconds</p>
        </div>

        <.form for={@form} action={~p"/register"} method="post" id="register-form" class="space-y-4">
          <UptimeComponents.custom_input
            field={@form[:email]}
            type="email"
            label="Email Address"
            placeholder="name@company.com"
            required
          />

          <UptimeComponents.custom_input
            field={@form[:password]}
            type="password"
            label="Password"
            placeholder="Min. 8 characters"
            required
          />

          <div class="pt-2">
            <UptimeComponents.primary_button type="submit" class="w-full">
              Sign Up
            </UptimeComponents.primary_button>
          </div>
        </.form>

        <div class="text-center border-t border-slate-50 pt-4">
          <p class="text-xs text-slate-400">
            Already have an account?
            <a href="/login" class="text-[hsl(268,60%,50%)] hover:underline font-semibold ml-1">Sign In</a>
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
