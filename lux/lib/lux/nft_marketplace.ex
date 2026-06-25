defmodule Lux.NFTMarketplace do
  @moduledoc """
  NFT Marketplace Data Aggregation System for Lux.

  Provides unified access to major NFT marketplaces including OpenSea, Blur, and X2Y2.
  Supports collection statistics, price tracking, sales monitoring, rarity calculation,
  trait analysis, market trends, listing management, and cross-marketplace comparison.
  """

  alias Lux.NFTMarketplace.{
    Collection,
    PriceTracker,
    SalesMonitor,
    RarityEngine,
    TraitAnalyzer,
    MarketTrends,
    ListingManager,
    CrossMarketplace
  }

  @doc """
  Fetches collection statistics from specified marketplace.
  """
  defdelegate get_collection_stats(collection_slug, opts \\ []), to: Collection

  @doc """
  Tracks price history and current floor price.
  """
  defdelegate track_price(collection_slug, opts \\ []), to: PriceTracker

  @doc """
  Monitors sales events in real-time.
  """
  defdelegate monitor_sales(collection_slug, opts \\ []), to: SalesMonitor

  @doc """
  Calculates rarity score for a given NFT.
  """
  defdelegate calculate_rarity(token_id, collection_slug, opts \\ []), to: RarityEngine

  @doc """
  Analyzes traits for a collection or specific NFT.
  """
  defdelegate analyze_traits(collection_slug, opts \\ []), to: TraitAnalyzer

  @doc """
  Analyzes market trends for collections or overall market.
  """
  defdelegate analyze_trends(opts \\ []), to: MarketTrends

  @doc """
  Manages listings across marketplaces.
  """
  defdelegate manage_listings(action, opts \\ []), to: ListingManager

  @doc """
  Compares data across multiple marketplaces.
  """
  defdelegate compare_marketplaces(collection_slug, opts \\ []), to: CrossMarketplace

  @doc """
  Aggregates comprehensive data for a collection across all supported features.
  """
  def aggregate_collection_data(collection_slug, opts \\ []) do
    marketplace = Keyword.get(opts, :marketplace, :opensea)

    with {:ok, stats} <- get_collection_stats(collection_slug, opts),
         {:ok, prices} <- track_price(collection_slug, opts),
         {:ok, sales} <- monitor_sales(collection_slug, opts),
         {:ok, trends} <- analyze_trends(Keyword.put(opts, :collection, collection_slug)) do
      {:ok,
       %{
         collection: collection_slug,
         marketplace: marketplace,
         stats: stats,
         prices: prices,
         sales: sales,
         trends: trends,
         timestamp: DateTime.utc_now()
       }}
    end
  end
end