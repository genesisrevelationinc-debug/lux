```diff
--- a/lux/lib/lux/analytics.ex
+++ b/lux/lib/lux/analytics.ex
@@ -0,0 +1,15 @@
+defmodule Lux.Analytics do
+  @moduledoc """
+  DeFi analytics integration with DeFiLlama and Dune Analytics.
+  Provides comprehensive protocol analysis including TVL tracking,
+  protocol metrics, yield analytics, and volume analysis.
+  """
+
+  alias Lux.Analytics.DefiLlama
+  alias Lux.Analytics.Dune
+  alias Lux.Analytics.Protocol
+  alias Lux.Analytics.Yield
+  alias Lux.Analytics.Volume
+  alias Lux.Analytics.Dashboard
+  alias Lux.Analytics.Alert
+
+  defdelegate get_tvl(protocol \\ nil), to: DefiLlama
+  defdelegate get_protocols, to: DefiLlama
+  defdelegate get_protocol_metrics(protocol_id), to: Protocol
+  defdelegate get_yields, to: Yield
+  defdelegate get_volume(protocol_id), to: Volume
+  defdelegate run_query(query_id, params), to: Dune
+  defdelegate get_dashboard, to: Dashboard
+  defdelegate subscribe_alert(alert_config), to: Alert
+end
--- /dev/null
+++ b/lux/lib/lux/analytics/defi_llama.ex
@@ -0,0 +1,147 @@
+defmodule Lux.Analytics.DefiLlama do
+  @moduledoc """
+  DeFiLlama API integration for TVL tracking and protocol metrics.
+  """
+
+  require Logger
+
+  @base_url "https://api.llama.fi"
+
+  @doc """
+  Get TVL data for all protocols or a specific protocol.
+  """
+  def get_tvl(protocol \\ nil) do
+    case protocol do
+      nil -> request("/protocols")
+      protocol_name -> request("/tvl/#{protocol_name}")
+    end
+  end
+
+  @doc """
+  Get list of all protocols with their TVL data.
+  """
+  def get_protocols do
+    request("/protocols")
+  end
+
+  @doc """
+  Get detailed data for a specific protocol.
+  """
+  def get_protocol_data(protocol) do
+    request("/protocol/#{protocol}")
+  end
+
+  @doc """
+  Get historical TVL data for a chain.
+  """
+  def get_historical_tvl(chain) do
+    request("/v2/historicalChainTvl/#{chain}")
+  end
+
+  @doc """
+  Get current TVL for all chains.
+  """
+  def get_chains_tvl do
+    request("/v2/chains")
+  end
+
+  @doc """
+  Get yields data from DeFiLlama yields API.
+  """
+  def get_yields do
+    request("/yields", "https://yields.llama.fi")
+  end
+
+  @doc """
+  Get pools data for yield analysis.
+  """
+  def get_yield_pools do
+    request("/pools", "https://yields.llama.fi")
+  end
+
+  @doc """
+  Get specific pool data.
+  """
+  def get_pool_data(pool_id) do
+    request("/chart/#{pool_id}", "https://yields.llama.fi")
+  end
+
+  defp request(endpoint, base_url \\ @base_url) do
+    url = base_url <> endpoint
+
+    case HTTPoison.get(url, [], timeout: 30_000, recv_timeout: 30_000) do
+      {:ok, %{status_code: 200, body: body}} ->
+        case Jason.decode(body) do
+          {:ok, data} -> {:ok, data}
+          {:error, reason} -> {:error, {:decode_failed, reason}}
+        end
+
+      {:ok, %{status_code: status, body: body}} ->
+        {:error, {:http_error, status, body}}
+
+      {:error, reason} ->
+        {:error, {:request_failed, reason}}
+    end
+  end
+end
--- /dev/null
+++ b/lux/lib/lux/analytics/dune.ex
@@ -0,0 +1,120 @@
+defmodule Lux.Analytics.Dune do
+  @moduledoc """
+  Dune Analytics API integration for custom queries and data access.
+  """
+
+  require Logger
+
+  @base_url "https://api.dune.com/api/v1"
+
+  @doc """
+  Execute a query and wait for results.
+  """
+  def execute_query(query_id, params \\ %{}) do
+    with {:ok, execution} <- run_query(query_id, params),
+         {:ok, results} <- get_execution_results(execution.execution_id) do
+      {:ok, results}
+    end
+  end
+
+  @doc """
+  Run a query and return execution metadata.
+  """
+  def run_query(query_id, params \\ %{}) do
+    body = %{
+      "query_parameters" => params,
+      "performance" => "medium"
+    }
+
+    request(:post, "/query/#{query_id}/execute", body)
+  end
+
+  @doc """
+  Get results from a query execution.
+  """
+  def get_execution_results(execution_id, opts \\ []) do
+    limit = Keyword.get(opts, :limit, 1000)
+    offset = Keyword.get(opts, :offset, 0)
+
+    request(:get, "/execution/#{execution_id}/results?limit=#{limit}&offset=#{offset}")
+  end
+
+  @doc """
+  Get status of a query execution.
+  """
+  def get_execution_status(execution_id) do
+    request(:get, "/execution/#{execution_id}/status")
+  end
+
+  @doc """
+  Cancel a running query execution.
+  """
+  def cancel_execution(execution_id) do
+    request(:post, "/execution/#{execution_id}/cancel")
+  end
+
+  @doc """
+  Get list of available queries for the authenticated user.
+  """
+  def list_queries(opts \\ []) do
+    limit = Keyword.get(opts, :limit, 100)
+    offset = Keyword.get(opts, :offset, 0)
+
+    request(:get, "/query/list?limit=#{limit}&offset=#{offset}")
+  end
+
+  defp request(method, endpoint, body \\ nil) do
+    url = @base_url <> endpoint
+    headers = [
+      {"Authorization", "Bearer #{api_key()}"},
+      {"Content-Type", "application/json"},
