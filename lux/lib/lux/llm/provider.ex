defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal provider interface for managing multiple LLM providers.
  Defines the contract that all LLM providers must implement.
  """

  alias Lux.LLM.Provider.Model

  @type completion_response :: %{
          content: String.t(),
          model: String.t(),
          usage: map(),
          finish_reason: String.t()
        }

  @type stream_chunk :: %{
          content: String.t() | nil,
          finish_reason: String.t() | nil
        }

  @type error :: {:error, term()}

  @doc "Returns the provider's name"
  @callback name() :: String.t()

  @doc "Returns list of available models for this provider"
  @callback available_models() :: [Model.t()]

  @doc "Checks if the provider is configured and available"
  @callback available?() :: boolean()

  @doc "Generates a completion for the given messages"
  @callback completion(messages :: [map()], opts :: keyword()) ::
              {:ok, completion_response()} | error()

  @doc "Generates a streaming completion for the given messages"
  @callback stream_completion(messages :: [map()], opts :: keyword()) ::
              {:ok, Enumerable.t()} | error()

  @doc "Returns the cost for a given model and token usage"
  @callback estimate_cost(model :: String.t(), tokens :: map()) :: Decimal.t() | nil

  @doc """
  Default implementation for checking availability based on API key presence.
 对于大多数提供者，可用性取决于API密钥是否存在。
  """
  defmacro __using__(opts) do
    quote do
      @behaviour Lux.LLM.Provider

      @impl true
      def available? do
        api_key = unquote(opts)[:api_key_env] || default_api_key_env()
        api_key != nil and api_key != ""
      end

      defp default_api_key_env do
        env_var = unquote(opts)[:api_key_env_var]
        if env_var, do: System.get_env(env_var), else: nil
      end

      defoverridable available?: 0
    end
  end
end