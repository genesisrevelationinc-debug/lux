defmodule Lux.NFTMarketplace.Listing do
  @moduledoc """
  Schema and functions for NFT listing data.
  """

  defstruct [
    :token_id,
    :collection_slug,
    :price,
    :currency,
    :seller,
    :marketplace,
    :listed_at,
    :expires_at
  ]

  @type t :: %__MODULE__{
          token_id: String.t(),
          collection_slug: String.t(),
          price: float(),
          currency: String.t(),
          seller: String.t(),
          marketplace: atom(),
          listed_at: DateTime.t(),
          expires_at: DateTime.t() | nil
        }
end