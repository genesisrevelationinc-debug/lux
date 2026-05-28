defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal provider interface for LLM providers.
  Defines the contract that all LLM providers must implement.
  """

  alias Lux.LLM.Schema

  @type model :: String.t()
  @type message :: %{role: String.t(), content: String.t()}
  @type completion_response :: {:ok, map()} | {:error, term()}
  @type stream_response :: Enumerable.t()

  @callback available_models() :: [model()]
  @callback chat_completion(messages :: [message()], opts :: keyword()) :: completion_response()
  @callback stream_chat_completion(messages :: [message()], opts :: keyword()) :: stream_response()
  @callback estimate_cost(model :: model(), input_tokens :: integer(), output_tokens :: integer()) ::
              Decimal.t() | float()
  @callback validate_config() :: :ok | {:error, term()}

  @doc """
  Gets the default model for a provider.
  """
  @callback default_model() :: model()

  @doc """
  Returns provider capabilities.
  """
  @callback capabilities() :: [atom()]

  @optional_callbacks [
    stream_chat_completion: 2,
    estimate_cost: 3,
    validate_config: 0,
    capabilities: 0
  ]

  @doc """
  Macro to implement the provider behaviour with defaults.
  """
  defmacro __using__(opts) do
    quote do
      @behaviour Lux.LLM.Provider

      @impl true
      def default_model do
        unquote(opts[:default_model]) || raise "default_model required"
      end

      @impl true
      def capabilities, do: unquote(opts[:capabilities] || [])

      @impl true
      def validate_config, do: :ok

      defoverridable validate_config: 0, capabilities: 0, default_model: 0
    end
  end
end

defmodule Lux.LLM.Schema do
  @moduledoc """
  Shared schemas and types for LLM operations.
  """

  defmodule Usage do
    @moduledoc "Token usage information."
    defstruct [:prompt_tokens, :completion_tokens, :total_tokens, :estimated_cost]

    @type t :: %__MODULE__{
            prompt_tokens: integer(),
            completion_tokens: integer(),
            total_tokens: integer(),
            estimated_cost: Decimal.t() | nil
          }
  end

  defmodule Completion do
    @moduledoc "LLM completion response."
    defstruct [:content, :model, :provider, :usage, :metadata, :finish_reason]

    @type t :: %__MODULE__{
            content: String.t(),
            model: String.t(),
            provider: module(),
            usage: Usage.t(),
            metadata: map(),
            finish_reason: String.t()
          }
  end
end