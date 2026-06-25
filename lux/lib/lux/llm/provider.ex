defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal provider interface for LLM providers.
  Defines the contract that all LLM providers must implement.
  """

  @type model :: String.t()
  @type message :: %{role: String.t(), content: String.t()}
  @type completion_opts :: keyword()
  @type completion_result :: {:ok, map()} | {:error, term()}

  @callback available_models() :: [model()]
  @callback complete(messages :: [message()], opts :: completion_opts()) :: completion_result()
  @callback stream_complete(messages :: [message()], opts :: completion_opts()) :: Enumerable.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour Lux.LLM.Provider

      def stream_complete(messages, opts) do
        Lux.LLM.Provider.default_stream_complete(__MODULE__, messages, opts)
      end

      defoverridable stream_complete: 2
    end
  end

  @doc """
  Default streaming implementation that wraps the complete/2 function.
  """
  def default_stream_complete(module, messages, opts) do
    Stream.resource(
      fn -> nil end,
      fn _ ->
        case module.complete(messages, opts) do
          {:ok, result} -> {[result], :done}
          {:error, reason} -> {[{:error, reason}], :done}
        end
      end,
      fn _ -> :ok end
    )
  end
end

defmodule Lux.LLM.Provider.Registry do
  @moduledoc """
  Registry for managing LLM providers.
  """

  use GenServer

  defmodule State do
    @moduledoc false
    defstruct providers: %{}, default_provider: nil
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %State供您选择，我将为您生成一个完整的 diff 解决方案。由于这是一个大型功能实现，我需要创建多个文件来构建完整的 LLM Provider Abstraction Layer。
