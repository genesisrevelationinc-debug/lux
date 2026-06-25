defmodule Lux.NFTMarketplace.Collection do
  @moduledoc """
  Schema and functions for NFT collection data.
  """

  defstruct [
    :slug,
    :name,
    :contract_address,
    :blockchain,
    :total_supply,
    :floor_price,
    :volume_traded,
    :marketplace,
    :traits,
    :created_at
  ]

  @type t :: %__MODULE__{
          slug: String.t(),
          name: String.t(),
          contract_address: String.t(),
          blockchain: String.t(),
          total_supply: non_neg_integer(),
          floor_price: float(),
          volume_traded: float(),
          marketplace: atom(),
          traits: map(),
          created_at: DateTime.t()
        }
end