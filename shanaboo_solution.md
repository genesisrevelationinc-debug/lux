Looking at the issue, I need to implement Hyperliquid integration for perpetual trading. Based on the repository structure and the issue requirements, I'll create the necessary files for this integration.

Let me create the Hyperliquid integration files in the lux directory since that's where the core functionality would reside based on the README structure.

```diff
--- /dev/null
+++ b/lux/lib/exchanges/hyperliquid.ex
@@ -0,0 +1,350 @@
+defmodule Lux.Exchanges.Hyperliquid do
+  @moduledoc """
+  Hyperliquid exchange integration for perpetual trading.
+  
+  This module provides functionality for:
+  - Order placement and management
+  - Position tracking
+  - Risk management
+  - Liquidation monitoring
+  - Margin management
+  - PnL tracking
+  """
+
+  alias Lux.Exchanges.Hyperliquid.{Position, Order, Risk, Margin}
+
+  @type credentials :: %{
+          api_key: String.t(),
+          api_secret: String.t(),
+          subaccount: String.t() | nil
+        }
+
+  @type config :: %{
+          credentials: credentials(),
+          testnet: boolean()
+        }
+
+  @doc """
+  Initialize Hyperliquid exchange connection
+  """
+  @spec init(config()) :: {:ok, pid()} | {:error, any()}
+  def init(config) do
+    # Initialize connection to Hyperliquid API
+    {:ok, spawn_link(fn -> exchange_loop(config) end)}
+  end
+
+  @doc """
+  Place a new order
+  """
+  @spec place_order(pid(), Order.t()) :: {:ok, Order.t()} | {:error, any()}
+  def place_order(pid, order) do
+    send(pid, {:place_order, self(), order})
+    receive do
+      {:order_placed, result} -> result
+      {:order_error, error} -> {:error, error}
+    after 5000 ->
+      {:error, :timeout}
+    end
+  end
+
+  @doc """
+  Cancel an existing order
+  """
+  @spec cancel_order(pid(), String.t()) :: {:ok, :cancelled} | {:error, any()}
+  def cancel_order(pid, order_id) do
+    send(pid, {:cancel_order, self(), order_id})
+    receive do
+      {:order_cancelled, result} -> result
+      {:cancel_error, error} -> {:error, error}
+    after 5000 ->
+      {:error, :timeout}
+    end
+  end
+
+  @doc """
+  Get current positions
+  """
+  @spec get_positions(pid()) :: {:ok, [Position.t()]} | {:error, any()}
+  def get_positions(pid) do
+    send(pid, {:get_positions, self()})
+    receive do
+      {:positions, positions} -> {:ok, positions}
+      {:positions_error, error} -> {:error, error}
+    after 5000 ->
+      {:error, :timeout}
+    end
+  end
+
+  @doc """
+  Get account risk metrics
+  """
+  @spec get_risk_metrics(pid()) :: {:ok, Risk.t()} | {:error, any()}
+  def get_risk_metrics(pid) do
+    send(pid, {:get_risk_metrics, self()})
+    receive do
+      {:risk_metrics, metrics} -> {:ok, metrics}
+      {:risk_metrics_error, error} -> {:error, error}
+    after 5000 ->
+      {:error, :timeout}
+    end
+  end
+
+  @doc """
+  Get account margin information
+  """
+  @spec get_margin_info(pid()) :: {:ok, Margin.t()} | {:error, any()}
+  def get_margin_info(pid) do
+    send(pid, {:get_margin_info, self()})
+    receive do
+      {:margin_info, info} -> {:ok, info}
+      {:margin_info_error, error} -> {:error, error}
+    after 5000 ->
+      {:error, :timeout}
+    end
+  end
+
+  @doc """
+  Set leverage for a symbol
+  """
+  @spec set_leverage(pid(), String.t(), integer()) :: {:ok, :set} | {:error, any()}
+  def set_leverage(pid, symbol, leverage) do
+    send(pid, {:set_leverage, self(), symbol, leverage})
+    receive do
+      {:leverage_set, result} -> result
+      {:leverage_error, error} -> {:error, error}
+    after 5000 ->
+      {:error, :timeout}
+    end
+  end
+
+  @doc """
+  Close all positions
+  """
+  @spec close_all_positions(pid()) :: {:ok, :closed} | {:error, any()}
+  def close_all_positions(pid) do
+    send(pid, {:close_all_positions, self()})
+    receive do
+      {:positions_closed, result} -> result
+      {:close_error, error} -> {:error, error}
+    after 5000 ->
+      {:error, :timeout}
+    end
+  end
+
+  @doc """
+  Get account PnL
+  """
+  @spec get_pnl(pid()) :: {:ok, map()} | {:error, any()}
+  def get_pnl(pid) do
+    send(pid, {:get_pnl, self()})
+    receive do
+      {:pnl, pnl} -> {:ok, pnl}
+      {:pnl_error, error} -> {:error, error}
+    after 5000 ->
+      {:error, :timeout}
+    end
+  end
+
+  # Private functions
+
+  defp exchange_loop(config) do
+    # Main exchange loop that handles API communication
+    # This would connect to Hyperliquid WebSocket and REST APIs
+    receive do
+      {:place_order, from, order} ->
+        result = do_place_order(config, order)
+        send(from, result)
+        exchange_loop(config)
+
+      {:cancel_order, from, order_id} ->
+        result = do_cancel_order(config, order_id)
+        send(from, result)
+        exchange_loop(config)
+
+      {:get_positions, from} ->
+        result = do_get_positions(config)
+        send(from, result)
+        exchange_loop(config)
+
+      {:get_risk_metrics, from} ->
+        result = do_get_risk_metrics(config)
+        send(from, result)
+        exchange_loop(config)
+
+      {:get_margin_info, from} ->
+        result = do