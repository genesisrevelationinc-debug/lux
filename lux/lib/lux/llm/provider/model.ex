defmodule Lux.LLM.Provider.Model do
  @moduledoc """
  Represents an LLM model with its capabilities and metadata.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          provider: atom(),
          capabilities: [atom()],
          context_window: integer(),
          max_output_tokens: integer(),
          pricing: %{
            input_per_1k: float(),
            output_per_1k: float()
          },
          features: [atom()],
          metadata: map()
        }

  defstruct [
    :id,
    :name,
    :provider,
    :capabilities,
    :context_window,
    :max_output_tokens,
    :pricing,
    :features,
    :metadata
  ]

  @doc """
  Creates a new Model struct.
  """
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Checks if a model supports a specific capability.
  """
  def supports?(%__MODULE__{capabilities: capabilities}, capability) do
    capability in capabilities
  end

  @doc """
  Calculates the estimated cost for a given token usage.
  """
  def estimate_cost(%__MODULE__{pricing: pricing}, input_tokens, output_tokens) do
    input_cost = (input_tokens / 1000) * pricing.input_per_1k
    output_cost = (output_tokens / 1000) * pricing.output_per_1k
    input_cost + output_cost
  end
end