 ```diff
--- /dev/null
+++ b/lux/lib/lux/llm/provider.ex
@@ -0,0 +1,95 @@
+defmodule Lux.LLM.Provider do
+  @moduledoc """
+  Universal provider interface for LLM providers.
+  Defines the contract that all LLM providers must implement.
+  """
+
+  @type model :: String.t()
+  @type message :: %{role: String.t(), content: String.t()}
+  @type completion_response :: %{
+          content: String.t(),
+          model: String.t(),
+          provider: module(),
+          usage: map(),
+          latency_ms: integer()
+        }
+  @type error_response :: %{error: String.t(), provider: module(), retryable: boolean()}
+
+  @callback available_models() :: [model()]
+  @callback chat_completion(messages :: [message()], opts :: keyword()) ::
+              {:ok, completion_response()} | {:error, error_response()}
+  @callback stream_completion(messages :: [message()], opts :: keyword()) ::
+              Enumerable.t()
+  @callback estimate_cost(model(), tokens :: integer()) :: float()
+  @callback validate_config() :: :ok | {:error, String.t()}
+end
+
+defmodule Lux.LLM.Provider.Base do
+  @moduledoc """
+  Base implementation with common provider functionality.
+  """
+
+  defmacro __using__(opts) do
+    quote do
+      @behaviour Lux.LLM.Provider
+
+      @default_timeout unquote(opts[:timeout] || 30_000)
+      @max_retries unquote(opts[:max_retries] || 3)
+
+      def stream_completion(messages, opts) do
+        Lux.LLM.Provider.Base.default_stream_impl(__MODULE__, messages, opts)
+      end
+
+      def validate_config do
+        :ok
+      end
+
+      defoverridable stream_completion: 2, validate_config: 0
+    end
+  end
+
+  def default_stream_impl(module, messages, opts) do
+    Stream.resource(
+      fn -> nil end,
+      fn _acc ->
+        case module.chat_completion(messages, opts) do
+          {:ok, response} -> {[response], :done}
+          {:error, error} -> {[error], :done}
+        end
+      end,
+      fn _ -> :ok end
+    )
+  end
+end
+--- /dev/null
+++ b/lux/lib/lux/llm/provider/openai.ex
@@ -0,0 +1,95 @@
+defmodule Lux.LLM.Provider.OpenAI do
+  @moduledoc """
+  OpenAI provider implementation.
+  """
+
+  use Lux.LLM.Provider.Base, timeout: 60_000, max_retries: 3
+
+  alias Lux.LLM.Monitoring.Metrics
+
+  @api_base "https://api.openai.com/v1"
+  @models [
+    "gpt-4o",
+    "gpt-4o-mini",
+    "gpt-4-turbo",
+    "gpt-4",
+    "gpt-3.5-turbo"
+  ]
+
+  @model_pricing %{
+    "gpt-4o" => %{input: 5.0, output: 15.0},
+    "gpt-4o-mini" => %{input: 0.15, output: 0.60},
+    "gpt-4-turbo" => %{input: 10.0, output: 30.0},
+    "gpt-4" => %{input: 30.0, output: 60.0},
+    "gpt-3.5-turbo" => %{input: 0.50, output: 1.50}
+  }
+
+  @impl true
+  def available_models, do: @models
+
+  @impl true
+  def chat_completion(messages, opts) do
+    model = opts[:model] || "gpt-4o"
+    api_key = get_api_key()
+
+    start_time = System.monotonic_time(:millisecond)
+
+    body = %{
+      model: model,
+      messages: messages,
+      max_tokens: opts[:max_tokens] || 4096,
+      temperature: opts[:temperature] || 0.7
+    }
+
+    headers = [
+      {"Authorization", "Bearer #{api_key}"},
+      {"Content-Type", "application/json"}
+    ]
+
+    case HTTPoison.post("#{@api_base}/chat/completions", Jason.encode!(body), headers, recv_timeout: 60_000) do
+      {:ok, %{status_code: 200, body: response_body}} ->
+        response = Jason.decode!(response_body)
+        latency = System.monotonic_time(:millisecond) - start_time
+
+        result = %{
+          content: get_in(response, ["choices", Access.at(0), "message", "content"]),
+          model: model,
+          provider: __MODULE__,
+          usage: response["usage"] || %{},
+          latency_ms: latency
+        }
+
+        Metrics.record_request(__MODULE__, model, latency, :success)
+        {:ok, result}
+
+      {:ok, %{status_code: status_code, body: body}} ->
+        latency = System.monotonic_time(:millisecond) - start_time
+        Metrics.record_request(__MODULE__, model, latency, :error)
+        {:error, %{error: "HTTP #{status_code}: #{body}", provider: __MODULE__, retryable: status_code in [429, 502, 503]}}
+
+      {:error, reason} ->
+        latency = System.monotonic_time(:millisecond) - start_time
+        Metrics.record_request(__MODULE__, model, latency, :error)
+        {:error, %{error: inspect(reason), provider: __MODULE__, retryable: true}}
+    end
+  end
+
+  @impl true
+  def estimate_cost(model, tokens) do
+    pricing = Map.get(@model_pricing, model, %{input: 0, output: 0})
+    # Cost per 1K tokens in USD
+    (pricing.input + pricing.output) * tokens / 1000 / 2
+  end
+
+  defp get_api_key do
+    System.get_env("OPENAI_API_KEY") ||
+      Application.get_env(:lux, :openai_api_key)
+  end
+end
+--- /dev/null
+++ b/lux/lib/lux/llm/provider/anthropic.ex
@@ -0,0 +1,93 @@
+defmodule Lux.LLM.Provider.Anthropic do
+  @moduledoc """
+  Anthropic Claude provider implementation.
+  """
+
+  use Lux.L