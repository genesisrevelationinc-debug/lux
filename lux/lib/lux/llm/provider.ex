defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal provider interface for managing multiple LLM providers.
  
  This module defines the behaviour and common interface for all LLM providers,
  enabling automatic model selection, fallback handling, and optimization features.
  """
  
  alias Lux.LLM.ProviderRegistry
  
  @type model :: String.t()
  @type prompt :: String.t() | list()
  @type options :: keyword()
  @type response :: {:ok, map()} | {:error, term()}
  @type provider_config :: %{
    required(:provider) => module(),
    required(:model) => model(),
    optional(:api_key) => String.t(),
    optional(:base_url) => String.t(),
    optional(:timeout) => non_neg_integer(),
    optional(:retries) => non_neg_integer(),
    optional(:any) => any()
  }
  
  @callback init(config :: map()) :: {:ok, term()} | {:error, term()}
  @callback complete(prompt :: prompt(), options :: options()) :: response()
  @callback chat(messages :: list(), options :: options()) :: response()
  @callback stream(prompt :: prompt(), options :: options()) :: Enumerable.t() | response()
  @callback count_tokens(text :: String.t(), model :: model()) :: non_neg_integer()
  @callback available_models() :: list(model())
  @callback estimate_cost(tokens :: non_neg_integer(), model :: model()) :: float()
  
  @doc """
  Gets the default provider configuration.
  """
  def default_config do
    Application.get_env(:lux, :llm_default_provider, %{
      provider: Lux.LLM.Providers.OpenAI,
 from_env(:lux, :llm_default_provider, %{
      provider: Lux.LLM.Providers.OpenAI,
      model: "gpt-4"
    })
  end
  
  @doc """
  Sends a completion request using the specified or default provider.
  """
  def complete(prompt, options \\ []) do
    provider = get_provider(options)
    provider.complete(prompt, options)
  end
  
  @doc """
  Sends a chat completion request using the specified or default provider.
  """
  def chat(messages, options \\ []) do
    provider = get_provider(options)
    provider.chat(messages, options)
  end
  
  @doc """
  Streams a completion using the specified or default provider.
  """
  def stream(prompt, options \\ []) do
    provider = get_provider(options)
    provider.stream(prompt, options)
  end
  
  @doc """
  Counts tokens for the given text and model.
  """
  def count_tokens(text, model \\ nil, options \\ []) do
    provider = get_provider(options)
    model = model || provider.config[:model]
    provider.count_tokens(text, model)
  end
  
  @doc """
  Gets available models from all registered providers or a specific provider.
  """
  def available_models(provider \\ nil) do
    if provider do
      provider.available_models()
    else
      ProviderRegistry.all_providers()
      |> Enum.flat_map(fn {_, mod} -> mod.available_models() end)
      |> Enum.uniq()
    end
  end
  
  @doc """
  Estimates the cost for a given number of tokens and model.
  """
  def estimate_cost(tokens, model, options \\ []) do
    provider = get_provider(options)
    provider.estimate_cost(tokens, model)
  end
  
  @doc """
  Selects the best provider based on criteria (cost, speed, quality).
  """
  def select_provider(criteria \\ :balanced) do
    ProviderRegistry.select_provider(criteria)
  end
  
  @doc """
  Executes a request with fallback handling across multiple providers.
  """
  def with_fallback(request_fn, providers \\ nil) do
    providers = providers || ProviderRegistry.all_providers()
    
    Enum.reduce candidate in providers do
      try do
        case request_fn.(candidate) do
          {:ok, result} -> {:ok, result}
          {:error, _} = error -> throw {:fallback, error}
        end
      catch
        {:fallback, error} -> error
        _ -> 
          if candidate == List.last(providers) do
            {:error, :all_providers_failed}
          else
            {:fallback, error}
          end
      end
    end
  end
  
  defp get_provider(options) do
    case Keyword.get(options, :provider) do
      nil -> 
        case ProviderRegistry.get_default() do
          nil -> raise "No default provider configured"
          provider -> provider
        end
      provider -> provider
    end
  end
end