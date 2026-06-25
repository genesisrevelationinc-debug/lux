defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal provider interface for LLM providers.
  Defines the contract that all LLM providers must implement.
  """

  alias Lux.LLM.{Request, Response, Config}

  @type model :: String.t()
  @type opts :: keyword()
  @type error :: {:error, term()}

  @doc """
  Returns the list of available models for this provider.
  """
  @callback available_models() :: [model()]

  @doc """
  Checks if the provider supports a given model.
  """
  @callback supports_model?(model()) :: boolean()

  @doc """
  Sends a chat completion request to the provider.
  """
  @callback chat_completion(Request.t(), opts()) :: {:ok, Response.t()} | error()

  @doc """
  Sends a streaming chat completion request to the provider.
  """
  @callback stream_chat_completion(Request.t(), opts()) :: Enumerable.t() | error()

  @doc """
  Returns the cost per token for a given model.
  """
  @callback cost_per_token(model()) :: {:ok, float()} | error()

  @doc """
  Returns the provider's name.
  """
  @callback name() :: String.t()

  @doc """
  Returns the provider's capabilities.
  """
  @callback capabilities() :: [atom()]

  @optional_callbacks [stream_chat_completion: 2]

  @doc """
  Validates a request before sending.
  """
  def validate_request(%Request{} = request) do
    with :ok <- validate_messages(request.messages),
         :ok <- validate_model(request.model) do
      :ok
    end
  end

  defp validate_messages([]), do: {:error, :empty_messages}
  defp validate_messages(messages) when is_list(messages), do: :ok
  defp validate_messages(_), do: {:error, :invalid_messages}

  defp validate_model(nil), do: {:error, :missing_model}
  defp validate_model(model) when is_binary(model), do: :ok
  defp validate_model(_), do: {:error, :invalid_model}
end

defmodule Lux.LLM.Request do
  @moduledoc """
  Represents a request to an LLM provider.
  """

  defstruct [
    :model,
    :messages,
    :temperature,
    :max_tokens,
    :top_p,
    :frequency_penalty,
    :presence_penalty,
    :stream,
    :tools,
    :tool_choice,
    :response_format,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
    model: String.t(),
    messages: [map()],
    temperature: float() | nil,
    max_tokens: integer() | nil,
    top_p: float() | nil,
    frequency_penalty: float() | nil,
    presence_penalty: float() | nil,
    stream: boolean() | nil,
    tools: [map()] | nil,
    tool_choice: map() | String.t() | nil,
    response_format: map() | nil,
    metadata: map()
  }

  @doc """
  Creates a new request with the given attributes.
  """
  def new(attrs \\ []) do
    struct!(__MODULE__, attrs)
  end
end

defmodule Lux.LLM.Response do
  @moduledoc """
  Represents a response from an LLM provider.
  """

  defstruct [
    :id,
    :model,
    :content,
    :usage,
    :finish_reason,
    :tool_calls,
    metadata: %{},
    created_at: nil
  ]

  @type t :: %__MODULE__{
    id: String.t() | nil,
    model: String.t(),
    content: String.t() | nil,
    usage: map() | nil,
    finish_reason: String.t() | nil,
    tool_calls: [map()] | nil,
    metadata: map(),
    created_at: DateTime.t() | nil
  }

  @doc """
  Creates a new response with the given attributes.
  """
  def new(attrs \\ []) do
    struct!(__MODULE__, Keyword.put_new(attrs, :created_at, DateTime.utc_now()))
  end
end
