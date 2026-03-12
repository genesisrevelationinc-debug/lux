defmodule Lux.Exchanges.Coinbase do
  @moduledoc """
  Coinbase Exchange integration for spot trading and advanced order management.

  This module provides REST API and WebSocket integration for:
  - Order placement and management
  - Market data streaming
  - Portfolio tracking
  - Account management
  - Historical data access

  ## Configuration

  Configure the exchange in your config:

      config :lux, :exchanges, :coinbase,
        api_key: "your_api_key",
        api_secret: "your_api_secret",
        passphrase: "your_passphrase",
        sandbox: false

  ## Examples

      # Get account balances
      {:ok, balances} = Coinbase.get_accounts()

      # Place a market order
      {:ok, order} = Coinbase.place_order(%{
        side: "buy",
        product_id: "BTC-USD",
        type: "market",
        size: "0.01"
      })

      # Get market data
      {:ok, ticker} = Coinbase.get_ticker("BTC-USD")
  """

  use GenServer
  use Lux.Exchange

  alias Lux.Exchanges.Coinbase.{REST, WebSocket}

  @type order :: %{
          id: String.t(),
          side: String.t(),
          product_id: String.t(),
          type: String.t(),
          size: String.t() | nil,
          price: String.t() | nil,
          status: String.t(),
          created_at: String.t(),
          filled_size: String.t(),
          fill_fees: String.t(),
          executed_value: String.t()
        }

  @type account :: %{
          id: String.t(),
          currency: String.t(),
          balance: String.t(),
          available: String.t(),
          hold: String.t(),
          profile_id: String.t()
        }

  @type ticker :: %{
          trade_id: integer(),
          price: String.t(),
          size: String.t(),
          bid: String.t(),
          ask: String.t(),
          volume: String.t(),
          time: String.t()
        }

  # Client API

  @doc """
  Starts the Coinbase exchange process.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets all accounts with balances.
  """
  @spec get_accounts() :: {:ok, [account()]} | {:error, any()}
  def get_accounts() do
    REST.get_accounts()
  end

  @doc """
  Gets a specific account by ID.
  """
  @spec get_account(String.t()) :: {:ok, account()} | {:error, any()}
  def get_account(account_id) do
    REST.get_account(account_id)
  end

  @doc """
  Gets account history for a specific account.
  """
  @spec get_account_history(String.t(), keyword()) :: {:ok, [map()]} | {:error, any()}
  def get_account_history(account_id, opts \\ []) do
    REST.get_account_history(account_id, opts)
  end

  @doc """
  Places a new order.
  """
  @spec place_order(map()) :: {:ok, order()} | {:error, any()}
  def place_order(order_params) do
    REST.place_order(order_params)
  end

  @doc """
  Cancels an order by ID.
  """
  @spec cancel_order(String.t()) :: {:ok, [String.t()]} | {:error, any()}
  def cancel_order(order_id) do
    REST.cancel_order(order_id)
  end

  @doc """
  Cancels all open orders.
  """
  @spec cancel_all_orders(keyword()) :: {:ok, [String.t()]} | {:error, any()}
  def cancel_all_orders(opts \\ []) do
    REST.cancel_all_orders(opts)
  end

  @doc """
  Gets order details by ID.
  """
  @spec get_order(String.t()) :: {:ok, order()} | {:error, any()}
  def get_order(order_id) do
    REST.get_order(order_id)
  end

  @doc """
  Lists all orders with optional filters.
  """
  @spec list_orders(keyword()) :: {:ok, [order()]} | {:error, any()}
  def list_orders(opts \\ []) do
    REST.list_orders(opts)
  end

  @doc """
  Gets ticker information for a product.
  """
  @spec get_ticker(String.t()) :: {:ok, ticker()} | {:error, any()}
  def get_ticker(product_id) do
    REST.get_ticker(product_id)
  end

  @doc """
  Gets order book for a product.
  """
  @spec get_order_book(String.t(), integer()) :: {:ok, map()} | {:error, any()}
  def get_order_book(product_id, level \\ 1) do
    REST.get_order_book(product_id, level)
  end

  @doc """
  Gets trade history for a product.
  """
  @spec get_trades(String.t(), keyword()) :: {:ok, [map()]} | {:error, any()}
  def get_trades(product_id, opts \\ []) do
    REST.get_trades(product_id, opts)
  end

  @doc """
  Gets candle data for a product.
  """
  @spec get_candles(String.t(), keyword()) :: {:ok, [[number()]]} | {:error, any()}
  def get_candles(product_id, opts \\ []) do
    REST.get_candles(product_id, opts)
  end

  @doc """
  Gets 24hr stats for a product.
  """
  @spec get_24hr_stats(String.t()) :: {:ok, map()} | {:error, any()}
  def get_24hr_stats(product_id) do
    REST.get_24hr_stats(product_id)
  end

  @doc """
  Gets all available products.
  """
  @spec get_products() :: {:ok, [map()]} | {:error, any()}
  def get_products() do
    REST.get_products()
  end

  @doc """
  Gets all available currencies.
  """
  @spec get_currencies() :: {:ok, [map()]} | {:error, any()}
  def get_currencies() do
    REST.get_currencies()
  end

  @doc """
  Gets current exchange time.
  """
  @spec get_time() :: {:ok, map()} | {:error, any()}
  def get_time() do
    REST.get_time()
  end

  @doc """
  Starts WebSocket connection for real-time data.
  """
  @spec start_websocket(keyword()) :: {:ok, pid()} | {:error, any()}
  def start_websocket(opts \\ []) do
    WebSocket.start_link(opts)
  end

  @doc """
  Subscribes to WebSocket channels.
  """
  @spec subscribe_websocket(pid(), [String.t()], keyword()) :: :ok | {:error, any()}
  def subscribe_websocket(pid, channels, opts \\ []) do
    WebSocket.subscribe(pid, channels, opts)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end
end