defmodule Lux.NFTMarketplace.Sale do
  @moduledoc """
  Schema and functions for NFTRulesments for NFT sale data.
  """

  defstruct [
    :token_id,
    :collection_slug,
    :price,
    :currency,
    :buyer,
    :seller,
    :marketplace,
    :sold_at,
    :transaction_hash
  ]

  @type t :: %__MODULE__{
          token_id: String.t(),
          collection_slug: String.t(),
          price: float(),
          currency: String.t(),
          buyer: String.t(),
          ...
          seller: String.t(),
          marketplace: atom(),
          sold_at: DateTime.t(),
          transaction_hash: String.t()
        }
end