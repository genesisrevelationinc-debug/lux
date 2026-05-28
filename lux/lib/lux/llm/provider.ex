defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal provider interface for LLM providers.
  Defines the contract that all LLM providers must implement.
  """

  alias Lux.LLM.Config

  @type model :: String.t()
  @type prompt :: String.t() | list()
  @type options :: keyword()
  @type response :: %{content: String.t(), metadata: map()}
  @type error :: {:error, term()}

  @callback available_models() :: [model()]
  @callback chat_completion(prompt(), options()) :: {:ok, response()} | error()
  @callback stream_completion(prompt(), options(), callback :: function()) :: :ok | error()
  @callback count_tokens(prompt(), model()) :: non_neg_integer()
  @callback supports_model?(model()) :: boolean()
  @callback default_config() :: keyword()

  @doc """
  Returns the list of available providers.
  """
  def available_providers do
    Lux.LLM.Registry.list_providers()
  end

  @doc """
  Gets a provider module by name.
  """
  def get_provider(name) when is_atom(name) do
    Lux.LLM.Registry.get(name)
  end

  @doc """
  Executes a chat completion with automatic provider selection.
  """
  def chat(prompt, opts \\ []) do
    provider = select_provider(opts)
    provider.chat_completion(prompt, opts)
  end

  @doc """
  Streams a chat completion with automatic provider selection.
  """
  def stream(prompt, opts \\ [], callback) do
    provider = select_provider(opts)
    provider.stream_completion(prompt, opts, callback)
  end

  defp select_provider(opts) do
    model = opts[:model]
    preferred = opts[:provider]

    cond do
      preferred && provider = Lux.LLM.Registry.get(preferred) ->
        provider

      model && provider = Lux.LLM.Registry.find_by_model(model) ->
        provider

      true ->
        Lux.LLM.Selector.select_provider(opts)
    end
  end
end