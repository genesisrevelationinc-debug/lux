defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal provider interface for managing multiple LLM providers.
  Defines the contract that all LLM providers must implement.
  """

  alias Lux.LLM.ProviderConfig

  @type model :: String.t()
  @type message :: %{role: String.t(), content: String.t()}
  @type completion_response :: %{
          content: String.t(),
          model: String.t(),
          provider: atom(),
          usage: map(),
          latency_ms: integer()
        }
  @type stream_chunk :: %{
          content: String.t() | nil,
          finish_reason: String.t() | nil,
          model: String.t(),
          provider: atom()
        }

  @callback init(config :: ProviderConfig.t()) :: {:ok, term()} | {:error, term()}
  @callback complete(
    model :: model(),
    messages :: [message()],
    opts :: keyword()
  ) :: {:ok, completion_response()} | {:error, term()}
  @callback stream(
    model :: model(),
    messages :: [message()],
    opts :: keyword()
  ) :: Enumerable.t()
  @callback list_models() :: [String.t()]
  @callback get_model_info(model :: model()) :: map() | nil

  @optional_callbacks stream: 3

  @doc """
  Default implementation for getting provider module from atom.
  """
  def provider_module(:openai), do: Lux.LLM.Providers.OpenAI
  def provider_module(:anthropic), do: Lux.LLM.Providers.Anthropic
  def provider_module(:google), do: Lux.LLM.Providers.Google
  def provider_module(:azure), do: Lux.LLM.Providers.Azure
  def provider_module(:local), do: Lux.LLM.Providers.Local
  def provider_module(_), do: nil

  @doc """
  Get all available provider types.
  """
  def available_providers do
    [:openai, :anthropic, :google, :azure, :local]
  end

  @doc """
  Check if a provider type is valid.
  """
  def valid_provider?(provider) when is_atom(provider) do
    provider in available_providers()
  end
  def valid_provider?(_), do: false
end