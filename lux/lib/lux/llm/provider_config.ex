defmodule Lux.LLM.ProviderConfig do
  @moduledoc """
  Configuration struct for LLM providers.
  """

  @type t :: %__MODULE__{
      provider: atom(),
      api_key: String.t() | nil,
      base_url: String.t() | nil,
      organization_id: String.t() | nil,
      default_model: String.t() | nil,
      timeout: integer(),
      max_retries: integer(),
      retry_delay: integer(),
      extra_headers: [{String.t(), String.t()}],
      metadata: map()
    }

  defstruct [
    :provider,
    :api_key,
    :base_url,
    :organization_id,
    :default_model,
    timeout: 30_000,
    max_retries: 3,
    retry_delay: 1000,
    extra_headers: [],
    metadata: %{}
  ]

  @doc """
  Create a new provider configuration.
  """
  def new(attrs \\ %{}) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Merge additional attributes into an existing config.
  """
  def merge(%__MODULE__{} = config, attrs) when is_map(attrs) do
    struct!(config, attrs)
  end

  @doc """
  Get a value from the config's metadata.
  """
  def get_metadata(%__MODULE__{metadata: metadata}, key, default \\ nil) do
    Map.get(metadata, key, default)
  end
end