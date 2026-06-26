defmodule Lux.Integrations.Uniswap.V3 do
  @moduledoc """
  Comprehensive Uniswap V3 integration for advanced liquidity management
  and optimal trading strategies.
  """

  alias Lux.Integrations.Uniswap.V3.{
    Pool,
    Position,
    LiquidityManager,
    FeeManager,
    PriceRangeOptimizer,
    PositionMonitor,
    Rebalancer
  }

  @doc """
  Creates a new liquidity position in a Uniswap V3 pool.
  """
  def create_position(params) do
    Position.create(params)
  end

  @doc """
  Manages multiple positions across different pools.
  """
  def manage_positions(positions) do
    Position.manage_multiple(positions)
  end

  @doc """
  Optimizes price ranges for concentrated liquidity.
  """
  def optimize_price_range(pool_data, strategy \\ :balanced) do
    PriceRangeOptimizer.optimize(pool_data, strategy)
  end

  @doc """
  Selects optimal fee tier based on market conditions.
  """
  def select_fee_tier(market_data) do
    Pool.select_optimal_fee_tier(market_data)
  end

  @doc """
  Collects and reinvests fees from a position.
  """
  def collect_and_reinvest(position_id, options \\ []) do
    FeeManager.collect_and_reinvest(position_id, options)
  end

  @doc """
  Monitors position health and returns status.
  """
  def monitor_position(position_id) do
    PositionMonitor.check_health(position_id)
  end

  @doc """
  Automatically rebalances a position based on strategy.
  """
  def rebalance_position(position_id, strategy) do
    Rebalancer.rebalance(position_id, strategy)
  end

  @doc """
  Calculates impermanent loss for a position.
  """
  def calculate_impermanent_loss(position, current_prices) do
    Position.calculate_impermanent_loss(position, current_prices)
  end

  @doc """
  Gets yield optimization recommendations.
  """
  def yield_optimization_recommendations(positions) do
    LiquidityManager.optimize_yield(positions)
  end

  @doc """
  Full position health dashboard data.
  """
  def position_dashboard(position_ids) when is_list(position_ids) do
    Enum.map(position_ids, &PositionMonitor.dashboard_data/1)
  end

  def position_dashboard(position_id) do
    PositionMonitor.dashboard_data(position_id)
  end
end