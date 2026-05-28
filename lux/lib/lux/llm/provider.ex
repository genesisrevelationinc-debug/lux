defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal provider interface for LLM providers.
  Defines the contract that all LLM providers must implement.
  """

  alias Lux.LLM.Config

  @type model :: String.t()
  @type message :: %{role: String.t(), content: String.t()}
  @type response :: %{content: String.t(), model: model(), usage: map()}
  @type error :: %{reason: atom(), message: String.t()}

  @callback available_models() :: [model()]
  @callback chat(messages :: [message()], config :: Config.t()) ::
              {:ok, response()} | {:error, error()}
  @callback complete(prompt :: String.t(), config :: Config.t()) ::
              {:ok, response()} | {:error, error()}
  @callback stream(messages :: [message()], config :: Config.t(), callback :: function()) ::
              {:ok, pid()} | {:error, error()}
  @callback estimate_cost(model :: model(), tokens :: non_neg_integer()) :: Decimal.t()
  @callback supports_capability?(model :: model(), capability :: atom()) :: boolean()

  @doc """
  Returns the default model for a provider.
  """
  @callback default_model() :: model()

  @doc """
  Validates if a configuration is valid for this provider.
  """
  @callback validate_config(config :: map()) :: :ok | {:error, String.t()}

  @optional_callbacks [stream: 3, estimate_cost: 2, supports_capability?: 2]
end

defmodule Lux.LLM.Config do
  @moduledoc """
  Configuration struct for LLM providers.
  """

  @type t :: %__MODULE__{
          provider: module(),
          model: String.t() | nil,
          temperature: float(),
          max_tokens: non_neg_integer() | nil,
          timeout: non_neg_integer(),
          retries: non_neg_integer(),
          api_key: String.t() | nil,
          base_url: String.t() | nil,
          extra_params: map()
        }

  defstruct [
    :provider,
    :model,
    :temperature,
    :max_tokens,
    :timeout,
    :retries,
    :api_key,
    :base_url,
    :extra_params
  ]
end