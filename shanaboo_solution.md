```diff
--- /dev/null
+++ b/lux/lib/lux/integrations/defi_analytics.ex
@@ -0,0 +1,212 @@
+defmodule Lux.Integrations.DefiAnalytics do
+  @moduledoc """
+  DeFi analytics integration with DeFiLlama and Dune Analytics.
+  Provides TVL tracking, protocol metrics, yield analytics, volume analysis,
+  custom query support, historical data access, and alert system.
+  """
+
+  alias Lux.Integrations.DefiAnalytics.DefiLlama
+  alias Lux.Integrations.DefiAnalytics.DuneAnalytics
+  alias Lux.Integrations.DefiAnalytics.Dashboard
+  alias Lux.Integrations.DefiAnalytics.AlertSystem
+
+  @type protocol_id :: String.t()
+  @type chain :: String.t()
+  @type timeframe :: :day | :week | :month | :year
+
+  # TVL Tracking
+
+  @doc """
+  Get current TVL for all protocols or a specific protocol.
+  """
+  @spec get_tvl(protocol_id() | nil) :: {:ok, map()} | {:error, term()}
+  def get_tvl(protocol_id \\ nil) do
+    DefiLlama.get_tvl(protocol_id)
+  end
+
+  @doc """
+  Get historical TVL data for a protocol.
+  """
+  @spec get_historical_tvl(protocol_id(), timeframe()) :: {:ok, list()} | {:error, term()}
+  def get_historical_tvl(protocol_id, timeframe \\ :day) do
+    DefiLlama.get_historical_tvl(protocol_id, timeframe)
+  end
+
+  @doc """
+  Get TVL for a specific chain.
+  """
+  @spec get_chain_tvl(chain()) :: {:ok, map()} | {:error, term()}
+  def get_chain_tvl(chain) do
+    DefiLlama.get_chain_tvl(chain)
+  end
+
+  # Protocol Metrics
+
+  @doc """
+  Get comprehensive metrics for a protocol.
+  """
+  @spec get_protocol_metrics(protocol_id()) :: {:ok, map()} | {:error, term()}
+  def get_protocol_metrics(protocol_id) do
+    DefiLlama.get_protocol_metrics(protocol_id)
+  end
+
+  @doc """
+  Get list of all protocols with basic info.
+  """
+  @spec list_protocols() :: {:ok, list()} | {:error, term()}
+  def list_protocols do
+    DefiLlama.list_protocols()
+  end
+
+  # Yield Analytics
+
+  @doc """
+  Get yield data for pools.
+  """
+  @spec get_yields(filters :: map()) :: {:ok, list()} | {:error, term()}
+  def get_yields(filters \\ %{}) do
+    DefiLlama.get_yields(filters)
+  end
+
+  @doc """
+  Get yield history for a specific pool.
+  """
+  @spec get_yield_history(String.t(), timeframe()) :: {:ok, list()} | {:error, term()}
+  def get_yield_history(pool_id, timeframe \\ :day) do
+    DefiLlama.get_yield_history(pool_id, timeframe)
+  end
+
+  # Volume Analysis
+
+  @doc """
+  Get volume data for DEXes.
+  """
+  @spec get_dex_volumes(chain() | nil) :: {:ok, map()} | {:error, term()}
+  def get_dex_volumes(chain \\ nil) do
+    DefiLlama.get_dex_volumes(chain)
+  end
+
+  @doc """
+  Get historical volume data.
+  """
+  @spec get_volume_history(chain(), timeframe()) :: {:ok, list()} | {:error, term()}
+  def get_volume_history(chain, timeframe \\ :day) do
+    DefiLlama.get_volume_history(chain, timeframe)
+  end
+
+  # Custom Query Support (Dune Analytics)
+
+  @doc """
+  Execute a custom Dune Analytics query.
+  """
+  @spec execute_query(String.t(), map()) :: {:ok, map()} | {:error, term()}
+  def execute_query(query_sql, parameters \\ %{}) do
+    DuneAnalytics.execute_query(query_sql, parameters)
+  end
+
+  @doc """
+  Get results from a previously executed query.
+  """
+  @spec get_query_results(String.t()) :: {:ok, map()} | {:error, term()}
+  def get_query_results(execution_id) do
+    DuneAnalytics.get_query_results(execution_id)
+  end
+
+  @doc """
+  Execute a parameterized query with parameters.
+  """
+  @spec execute_parameterized_query(String.t(), map()) :: {:ok, map()} | {:error, term()}
+  def execute_parameterized_query(query_id, parameters) do
+    DuneAnalytics.execute_parameterized_query(query_id, parameters)
+  end
+
+  # Historical Data Access
+
+  @doc """
+  Get historical data with flexible parameters.
+  """
+  @spec get_historical_data(type :: atom(), protocol_id(), timeframe()) ::
+          {:ok, list()} | {:error, term()}
+  def get_historical_data(type, protocol_id, timeframe) do
+    case type do
+      :tvl -> get_historical_tvl(protocol_id, timeframe)
+      :volume -> get_volume_history(protocol_id, timeframe)
+      :yield -> get_yield_history(protocol_id, timeframe)
+      _ -> {:error, :unsupported_type}
+    end
+  end
+
+  # Dashboard
+
+  @doc """
+  Get dashboard data for a protocol.
+  """
+  @spec get_dashboard_data(protocol_id()) :: {:ok, map()} | {:error, term()}
+  def get_dashboard_data(protocol_id) do
+    Dashboard.get_data(protocol_id)
+  end
+
+  # Alert System
+
+  @doc """
+  Create a new alert.
+  """
+  @spec create_alert(map()) :: {:ok, map()} | {:error, term()}
+  def create_alert(alert_config) do
+    AlertSystem.create_alert(alert_config)
+  end
+
+  @doc """
+  Check all alerts and trigger if conditions are met.
+  """
+  @spec check_alerts() :: {:ok, list()} | {:error, term()}
+  def check_alerts do
+    AlertSystem.check_alerts()
+  end
+end
--- /dev/null
+++ b/lux/lib/lux/integrations/defi_analytics/defi_llama.ex
@@ -0,0 +1,196 @@
+defmodule Lux.Integrations.DefiAnalytics.DefiLlama do
