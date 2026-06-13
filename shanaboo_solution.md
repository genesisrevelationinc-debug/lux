 ```diff
--- /dev/null
+++ b/lux/lib/lux/exchanges/hyperliquid.ex
@@ -0,0 +1,102 @@
+defmodule Lux.Exchanges.Hyperliquid do
+  @moduledoc """
+  Hyperliquid exchange integration for perpetual trading.
+
+  Provides position management, leverage control, risk monitoring,
+  order execution, liquidation protection, PnL tracking, and margin management.
+  """
+
+  alias Lux.Exchanges.Hyperliquid.API
+  alias Lux.Exchanges.Hyperliquid.Orders
+  alias Lux.Exchanges.Hyperliquid.Positions
+  alias Lux.Exchanges.Hyperliquid.Risk
+  alias Lux.Exchanges.Hyperliquid.Margin
+
+  @type order_side :: :buy | :sell
+  @type order_type :: :market | :limit | :stop | :stop_limit
+  @type position_side :: :long | :short
+
+  # Order Management
+
+  @doc """
+  Place a new order on Hyperliquid.
+  """
+  @spec place_order(map()) :: {:ok, map()} | {:error, term()}
+  def place_order(params) do
+    Orders.place(params)
+  end
+
+  @doc """
+  Cancel an existing order.
+  """
+  @spec cancel_order(String.t()) :: {:ok, map()} | {:error, term()}
+  def cancel_order(order_id) do
+    Orders.cancel(order_id)
+  end
+
+  @doc """
+  Get order status.
+  """
+  @spec get_order(String.t()) :: {:ok, map()} | {:error, term()}
+  def get_order(order_id) do
+    Orders.get(order_id)
+  end
+
+  # Position Management
+
+  @doc """
+  Get all open positions.
+  """
+  @spec get_positions() :: {:ok, list(map())} | {:error, term()}
+  def get_positions do
+    Positions.list()
+  end
+
+  @doc """
+  Get a specific position by asset.
+  """
+  @spec get_position(String.t()) :: {:ok, map()} | {:error, term()}
+  def get_position(asset) do
+    Positions.get(asset)
+  end
+
+  # Risk Management
+
+  @doc """
+  Set leverage for a specific asset.
+  """
+  @spec set_leverage(String.t(), pos_integer()) :: {:ok, map()} | {:error, term()}
+  def set_leverage(asset, leverage) do
+    Risk.set_leverage(asset, leverage)
+  end
+
+  @doc """
+  Get current risk metrics.
+  """
+  @spec get_risk_metrics() :: {:ok, map()} | {:error, term()}
+  def get_risk_metrics do
+    Risk.get_metrics()
+  end
+
+  # Margin Management
+
+  @doc """
+  Update margin for a position.
+  """
+  @spec update_margin(String.t(), number(), :add | :remove) :: {:ok, map()} | {:error, term()}
+  def update_margin(asset, amount, action) do
+    Margin.update(asset, amount, action)
+  end
+
+  @doc """
+  Get margin requirements for an asset.
+  """
+  @spec get_margin_requirements(String.t()) :: {:ok, map()} | {:error, term()}
+  def get_margin_requirements(asset) do
+    Margin.get_requirements(asset)
+  end
+end
+--- /dev/null
+++ b/lux/lib/lux/exchanges/hyperliquid/api.ex
@@ -0,0 +1,118 @@
+defmodule Lux.Exchanges.Hyperliquid.API do
+  @moduledoc """
+  Low-level HTTP client for Hyperliquid API.
+  """
+
+  require Logger
+
+  @base_url "https://api.hyperliquid.xyz"
+  @timeout 30_000
+
+  # Public API
+
+  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
+  def get(endpoint, params \\ []) do
+    url = build_url(endpoint, params)
+
+    case HTTPoison.get(url, [], timeout: @timeout, recv_timeout: @timeout) do
+      {:ok, %{status_code: 200, body: body}} ->
+        Jason.decode(body)
+
+      {:ok, %{status_code: status, body: body}} ->
+        Logger.warning("Hyperliquid API error: status=#{status}, body=#{body}")
+        {:error, {:http_error, status, body}}
+
+      {:error, reason} ->
+        Logger.error("Hyperliquid API request failed: #{inspect(reason)}")
+        {:error, reason}
+    end
+  end
+
+  @spec post(String.t(), map()) :: {:ok, map()} | {:error, term()}
+  def post(endpoint, body) do
+    url = @base_url <> endpoint
+
+    headers = [
+      {"Content-Type", "application/json"},
+      {"Accept", "application/json"}
+    ]
+
+    case HTTPoison.post(url, Jason.encode!(body), headers,
+           timeout: @timeout,
+           recv_timeout: @timeout
+         ) do
+      {:ok, %{status_code: status, body: resp_body}} when status in 200..299 ->
+        Jason.decode(resp_body)
+
+      {:ok, %{status_code: status, body: resp_body}} ->
+        Logger.warning("Hyperliquid API error: status=#{status}, body=#{resp_body}")
+        {:error, {:http_error, status, resp_body}}
+
+      {:error, reason} ->
+        Logger.error("Hyperliquid API request failed: #{inspect(reason)}")
+        {:error, reason}
+    end
+  end
+
+  # Authenticated API
+
+  @spec post_authenticated(String.t(), map(), map()) :: {:ok, map()} | {:error, term()}
+  def post_authenticated(endpoint, body, credentials) do
+    url = @base_url <> endpoint
+    timestamp = System.system_time(:millisecond)
+
+    payload = Map.put(body, "timestamp", timestamp)
+    signature = sign_request(payload, credentials)
+
+    headers = [
+      {"Content-Type", "application/json"},
+      {"Accept", "application/json"},
+      {"X-HL-API-Key", credentials.api_key},
+      {"X-HL-Signature", signature},
+      {"X-HL-Timestamp", to_string(timestamp)}
+    ]
+
+    case HTTPoison.post(url, Jason.encode!(payload), headers,
+           timeout: @timeout,
+           recv_timeout: @timeout
+         ) do
+      {:ok, %{status_code: status, body