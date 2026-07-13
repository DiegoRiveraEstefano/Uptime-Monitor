defmodule UptimeMonitor.Monitors.HttpChecker do
  @moduledoc """
  Executes HTTP checks using Req and runs assertions to determine health status.
  """

  alias UptimeMonitor.Monitors.Monitor

  @type check_response ::
          {:ok, latency_ms :: pos_integer(), status_code :: integer()}
          | {:error, latency_ms :: pos_integer(), reason :: String.t(), body :: String.t() | nil}

  @doc """
  Runs an availability check on a monitor.
  """
  @spec run(Monitor.t()) :: check_response()
  def run(%Monitor{} = monitor) do
    start_time = System.monotonic_time(:millisecond)

    # Configure Headers
    headers = Map.to_list(monitor.encrypted_headers || %{})

    # Perform Request
    case Req.request(
           method: :get,
           url: monitor.url,
           headers: headers,
           connect_options: [timeout: 5000],
           receive_timeout: 5000,
           retry: false
         ) do
      {:ok, %Req.Response{status: status, body: body}} ->
        end_time = System.monotonic_time(:millisecond)
        latency = max(end_time - start_time, 1)

        # Check Assertions (Status Code must be 2xx or 3xx)
        if status >= 200 and status < 400 do
          {:ok, latency, status}
        else
          body_snippet = parse_body(body)
          {:error, latency, "HTTP status #{status}", body_snippet}
        end

      {:error, %{reason: reason}} ->
        end_time = System.monotonic_time(:millisecond)
        latency = max(end_time - start_time, 1)
        {:error, latency, "Connection error: #{inspect(reason)}", nil}

      {:error, reason} ->
        end_time = System.monotonic_time(:millisecond)
        latency = max(end_time - start_time, 1)
        {:error, latency, "Connection error: #{inspect(reason)}", nil}
    end
  end

  defp parse_body(body) when is_binary(body), do: body
  defp parse_body(body) when is_map(body), do: Jason.encode!(body)
  defp parse_body(_), do: nil
end
