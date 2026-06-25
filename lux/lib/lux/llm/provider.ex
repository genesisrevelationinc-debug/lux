defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal provider interface for managing multiple LLM providers.
  Defines the contract that all LLM providers must implement.
 certified """

  alias Lux.LLM.Provider.Model

  @type provider_id :: atom()
  @type model_id :: String.t()
  @type request :: %{
          optional(:model) => model_id(),
          optional(:messages) => list(),
          optional(:temperature) => float(),
          optional(:max_tokens) => integer(),
          optional(:stream) => boolean(),
          optional(:tools) => list(),
          optional(:tool_choice) => any(),
          optional(:response_format) => map(),
          optional(:extra) => map()
        }
  @type response :: %{
          id: String.t(),
          model: model_id(),
          provider: provider_id(),
          content: String.t() | nil,
          tool_calls: list() | nil,
          usage: %{
            prompt_tokens: integer(),
            completion_tokens: integer(),
            total_tokens: integer()
          },
          finish_reason: String.t(),
          created_at: DateTime.t(),
          raw: map()
        }
  @type error :: %{
          type: atom(),
          message: String.t(),
          code: String.t() | nil,
          details: map() | nil
        }
  @type stream_chunk :: %{
          id: String.t(),
          content: String.t() | nil,
          tool_calls: list() | nil,
          finish_reason: String.t() | nil,
          usage: map() | nil
        }

  @callback init(opts :: keyword()) :: {:ok, map()} | {:error, term()}
  @callback chat(request(), config :: map()) :: {:ok, response()} | {:error, error()}
  @callback complete(request(), config :: map()) :: {:ok, response()} | {:error, error()}
  @callback stream(request(), config :: map()) :: Enumerable.t() | {:error, error()}
  @callback embed(text :: String.t() | list(), config :: map()) :: {:ok, list()} | {:error, error()}
  @callback list_models(config :: map()) :: {:ok, list(Model.t())} | {:error, error()}
  @callback get_model(model_id(), config :: map()) :: {:ok, Model.t()} | {:error, error()}
  @callback validate_config(config :: map()) :: :ok | {:error, String.t()}

  @optional_callbacks [stream: 2, embed: 2]

  @doc """
  Makes a chat completion request to the specified provider.
  """
  def chat(provider_module, request, config) do
    with :ok <- validate_request(request),
         :ok <- provider_module.validate_config(config) do
      provider_module.chat(request, config)
    end
  end

  @doc """
  Streams a chat completion response.
  """
  def stream(provider_module, request, config) do
    with :ok <- validate_request(request),
         :ok <- provider_module.validate_config(config) do
      provider_module.stream(request, config)
    end
  end

  @doc """
  Validates a request structure.
  """
  def validate_request(request) when is_map(request) do
    cond do
      not Map.has_key?(request, :messages) and not Map.has_key?(request, "messages") ->
        {:error, %{type: :validation_error, message: "Request must contain :messages", code: nil, details: nil}}

      true ->
        :ok
    end
  end

  def validate_request(_), do: {:error, %{type: :validation_error, message: "Request must be a map", code: nil, details: nil}}

  @doc """
  Builds a standard response from provider-specific data.
  """
  def build_response(attrs) do
    Map.merge(%{
      id: nil,
      content: nil,
      tool_calls: nil,
      usage: %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0},
      finish_reason: nil,
      created_at: DateTime.utc_now(),
      raw: %{}
    }, attrs)
  end
end