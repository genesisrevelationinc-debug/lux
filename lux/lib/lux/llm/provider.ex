defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal provider interface for LLM providers.
  Defines the contract that all LLM providers must implement.
  """

  @type model :: String.t()
  @type prompt :: String.t() | list()
  @type options :: keyword()
  @type response :: {:ok, map()} | {:error, term()}
  @type stream_callback :: (String.t() -> any())

  @callback chat_completion(prompt(), model(), options()) :: response()
  @callback stream_completion(prompt(), model(), stream_callback(), options()) :: response()
  @callback list_models() :: {:ok, list(model())} | {:error, term()}
  @callback get_model_info(model()) :: {:ok, map()} | {:error, term()}
  @callback count_tokens(prompt(), model()) :: {:ok, non_neg_integer()} | {:error, term()}
  @callback validate_config() :: :ok | {:error, term()}

  @doc """
  Returns the default model for this provider.
  """
  @callback default_model() :: model()

  @doc """
  Returns the provider name.
  """
  @callback name() :: String.t()

  @doc """
  Returns the provider's capabilities.
  """
  @callback capabilities() :: list(atom())

  defmacro __using__(_opts) do
    quote do
      @behaviour Lux.LLM.Provider

      def stream_completion(prompt, model, callback, options) do
        # Default implementation: simulate streaming by chunking the response
        case chat_completion(prompt, model, options) do
          {:ok, %{content: content} = response} ->
            # Stream the content in chunks
            chunk_size = 10
            content
            |> String.graphemes()
            |> Enum.chunk_every(chunk_size)
            |> Enum.each(fn chunk ->
              callback.(Enum.join(chunk))
            end)
            {:ok, response}

          {:error, _} = error ->
            error
        end
      end

      def validate_config do
        :ok
      end

      def default_model do
        "default"
      end

      defoverridable stream_completion: 4, validate_config: 0, default_model: 0
    end
  end
end