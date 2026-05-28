defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal LLM Provider Interface
  
  This module defines the behaviour and implementation for LLM providers
  with automatic model selection, fallback handling, and optimization features.
  """

  @doc """
  Callback for generating completions from an LLM provider
  """
  @callback generate(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}

  @doc """
  Callback for getting provider information
  """
  @callback info() :: map()

  @doc """
  Callback for getting provider capabilities
  """
  @callback capabilities() :: map()

  @typedoc "LLM Provider configuration"
  @type provider_config :: %{
    required(:type) => atom(),
    required(:api_key) => String.t(),
    optional(:endpoint) => String.t(),
    optional(:default_model) => String.t(),
    optional(:models) => [String.t()],
    optional(:cost_per_token) => float(),
    optional(:max_tokens) => integer()
  }

  @typedoc "LLM Generation options"
  @type generation_options :: [
    {:model, String.t()} |
    {:temperature, float()} |
    {:max_tokens, integer()} |
    {:stop_sequences, [String.t()]} |
    {:stream, boolean()}
  ]

  @doc """
  Generates a completion using the specified provider
  """
  @spec generate(provider_config(), String.t(), generation_options()) :: 
    {:ok, String.t(), map()} | {:error, any()}
  def generate(provider_config, prompt, options \\ []) do
    provider_module = get_provider_module(provider_config.type)
    
    case provider_module.generate(prompt, options ++ provider_config_to_options(provider_config)) do
      {:ok, result} -> 
        usage_info = %{
          provider: provider_config.type,
          model: options[:model] || provider_config[:default_model],
          tokens_used: estimate_tokens(prompt, result),
          cost: calculate_cost(provider_config, options[:model] || provider_config[:default_model])
        }
        {:ok, result, usage_info}
      error -> error
    end
  end

  @doc """
  Gets information about the provider
  """
  @spec info(provider_config()) :: map()
  def info(provider_config) do
    provider_module = get_provider_module(provider_config.type)
    provider_module.info()
  end

  @doc """
  Gets capabilities of the provider
  """
  @spec capabilities(provider_config()) :: map()
  def capabilities(provider_config) do
    provider_module = get_provider_module(provider_config.type)
    provider_module.capabilities()
  end

  defp get_provider_module(:openai), do: Lux.LLM.Providers.OpenAI
  defp get_provider_module(:anthropic), do: Lux.LLM.Providers.Anthropic
  defp get_provider_module(:ollama), do: Lux.LLM.Providers.Ollama
  defp get_provider_module(:google), do: Lux.LLM.Providers.Google
  defp get_provider_module(_), do: Lux.LLM.Providers.OpenAI

  defp provider_config_to_options(config) do
    opts = []
    if config[:api_key], do: opts = [{:api_key, config[:api_key]} | opts]
    if config[:endpoint], do: opts = [{:endpoint, config[:endpoint]} | opts]
    opts
  end

  defp estimate_tokens(prompt, _response) do
    # Simple token estimation - in reality this would be more sophisticated
    String.length(prompt) |> div(4)
  end

  defp calculate_cost(provider_config, _model) do
    # Placeholder for cost calculation logic
    # In reality this would use actual pricing data
    provider_config[:cost_per_token] || 0.0
  end
end