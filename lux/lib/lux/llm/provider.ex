defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal provider interface for managing multiple LLM providers.
  Defines the contract that all LLM providers must implement.
  """

  alias Lux.LLM.ProviderConfig

  @type model :: String.t()
  @type prompt :: String.t() | list()
  @type options :: keyword()
  @type response :: {:ok, map()} | {:error, term()}
  @type stream_callback :: (String.t() -> any())

  @callback available_models() :: list(model())
  @callback chat_completion(prompt(), model(), options()) :: response()
  @callback stream_completion(prompt(), model(), options(), stream_callback()) :: response()
  @callback count_tokens(prompt(), model()) :: non_neg_integer()
  @callback supports_streaming?(model()) :: boolean()
  @callback supports_functions?(model()) :: boolean()
  @callback estimate_cost(prompt(), model(), options()) :: float()

  @doc """
  Returns the default provider configuration.
  """
  def default_config do
    %ProviderConfig{
      provider: Application.get_env(:lux, :default_llm_provider, :openai),
      model: Application.get_env(:lux, :default_llm_model, "gpt-4"),
      temperature: 0.7,
      max_tokens: 2048,
      timeout: 30_000
    }
  end

  @doc """
  Validates if a provider module implements the required callbacks.
  """
  def valid_provider?(module) when is_atom(module) do
    behaviours = module.module_info(:attributes)[:behaviour] || []
    __MODULE__ in behaviours
  end

  def valid_provider?(_), do: false
end

defmodule Lux.LLM.ProviderConfig do
  @moduledoc """
  Configuration struct for LLM providers.
  """

  defstruct [
    :provider,
    :model,
    :temperature,
    :max_tokens,
    :timeout,
    :api_key,
    :base_url,
    :extra_headers,
    :retry_policy,
    :fallback_chain
  ]

  @type t :: %__MODULE__{
    provider: atom(),
    model: String.t(),
    temperature: float(),
    max_tokens: pos_integer(),
    timeout: pos_integer(),
    api_key: String.t() | nil,
    base_url: String.t() | nil,
    extra_headers: list(),
    retry_policy: map() | nil,
    fallback_chain: list()
  }
end

defmodule Lux.LLM.ProviderResponse do
  @moduledoc """
  Standardized response structure from LLM providers.
  """

  defstruct [
    :content,
    :model,
    :provider,
    :usage,
    :latency_ms,
    :finish_reason,
    :metadata
  ]

  @type t :: %__MODULE__{
    content: String.t() | map(),
    model: String.t(),
    provider: atom(),
    usage: map(),
    latency_ms: non_neg_integer(),
    finish_reason: String.t(),
    metadata: map()
  }
end

defmodule Lux.LLM.ProviderError do
  @moduledoc """
  Standardized error structure for LLM provider failures.
  """
  defexception [:message, :provider, :code, :retryable]

  @type t :: %__MODULE__{
    message: String.t(),
    provider: atom(),
    code: atom() | String.t(),
    retryable: boolean()
  }
end