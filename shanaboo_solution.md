 ```diff
--- a/lux/lib/lux/llm.ex
+++ b/lux/lib/lux/llm.ex
@@ -0,0 +1,316 @@
+defmodule Lux.LLM do
+  @moduledoc """
+  API for interacting with LLM providers through the universal provider interface.
+
+  This module provides a high-level API for:
+  - Generating text completions
+  - Selecting optimal providers and models
+  - Handling fallbacks automatically
+  - Tracking costs and performance
+  - Caching responses
+
+  ## Configuration
+
+  Configure providers in your application config:
+
+      config :lux, :llm,
+        default_provider: :openai,
+        providers: [
+          openai: [
+            module: Lux.LLM.Providers.OpenAI,
+            api_key: System.get_env("OPENAI_API_KEY"),
+            models: ["gpt-4", "gpt-3.5-turbo"],
+            default_model: "gpt-4",
+            priority: 1
+          ],
+          anthropic: [
+            module: Lux.LLM.Providers.Anthropic,
+            api_key: System.get_env("ANTHROPIC_API_KEY"),
+            models: ["claude-3-opus", "claude-3-sonnet"],
+            default_model: "claude-3-opus",
+            priority: 2
+          ]
+        ],
+        cache: [
+          enabled: true,
+          ttl: 300_000  # 5 minutes
+        ],
+        fallback: [
+          enabled: true,
+          max_retries: 3,
+          retry_delay: 1000
+        ]
+
+  ## Basic Usage
+
+  Generate a simple completion:
+
+      iex> Lux.LLM.complete("What is the capital of France?")
+      {:ok, "The capital of France is Paris."}
+
+  Use a specific provider:
+
+      iex> Lux.LLM.complete("Hello", provider: :anthropic)
+      {:ok, "Hello! How can I help you today?"}
+
+  Use a specific model:
+
+      iex> Lux.LLM.complete("Hello", model: "gpt-3.5-turbo")
+      {:ok, "Hello! How can I help you today?"}
+
+  ## Advanced Usage
+
+  Streaming responses:
+
+      iex> Lux.LLM.complete("Tell me a story", stream: true, stream_to: self())
+      {:ok, :streaming}
+
+  With structured output:
+
+      iex> Lux.LLM.complete("Extract the name", schema: %{name: :string})
+      {:ok, %{name: "John Doe"}}
+
+  With monitoring:
+
+      iex> Lux.LLM.complete("Hello", track: true)
+      {:ok, "Hello!", %Lux.LLM.Metrics{...}}
+  """
+
+  alias Lux.LLM.{
+    Provider,
+    ProviderRegistry,
+    ModelSelector,
+    FallbackHandler,
+    CostTracker,
+    PerformanceMonitor,
+    Cache
+  }
+
+  require Logger
+
+  @type completion_opts :: [
+    provider: atom(),
+    model: String.t(),
+    temperature: float(),
+    max_tokens: integer(),
+    top_p: float(),
+    stream: boolean(),
+    stream_to: pid() | atom(),
+    schema: map(),
+    track: boolean(),
+    cache: boolean(),
+    fallback: boolean(),
+    timeout: integer()
+  ]
+
+  @type completion_result :: {:ok, String.t() | map()} | {:ok, String.t(), map()} | {:error, term()}
+
+  @doc """
+  Generates a text completion using the configured or specified provider.
+
+  ## Options
+
+  - `:provider` - Specific provider to use (e.g., `:openai`, `:anthropic`)
+  - `:model` - Specific model to use
+  - `:temperature` - Sampling temperature (0.0 to 2.0)
+  - `:max_tokens` - Maximum tokens to generate
+  - `:top_p` - Nucleus sampling parameter
+  - `:stream` - Enable streaming (default: false)
+  - `:stream_to` - Process to receive stream chunks
+  - `:schema` - Expected output schema for structured responses
+  - `:track` - Return metrics alongside the response能结果 (default: false)
+  - `:cache` - Use response cache (default: true)
+  - `:fallback` - Enable fallback to other providers (default: true)
+  - `:timeout` - Request timeout in milliseconds
+  """
+  @spec complete(String.t(), keyword()) :: completion_result()
+  def complete(prompt, opts \\ []) do
+    start_time = System.monotonic_time()
+    cache_key = if Keyword.get(opts, :cache, true), do: Cache.key(prompt, opts), else: nil
+
+    # Try cache first
+    with :miss <- maybe_read_cache(cache_key),
+         {:ok, provider, model} <- select_provider_and_model(opts),
+         {:ok, result, metrics} <- execute_with_fallback(provider, model, prompt, opts) do
+
+      # Write to cache if enabled
+      :ok = maybe_write_cache(cache_key, result)
+
+      # Track cost and performance
+      track_metrics(metrics, provider, model, prompt, start_time)
+
+      return_result(result, metrics, opts)
+    else
+      {:hit, cached_result} ->
+        Logger.debug("LLM cache hit for prompt")
+        return_result(cached_result, %{}, opts)
+
+      {:error, reason} ->
+        Logger.error("LLM completion failed: #{inspect(reason)}")
+        {:error, reason}
+    end
+  end
+
+  @doc """
+  Generates a chat completion from a list of messages.
+
+  Messages should be in the format: `[%{"role" => "user", "content" => "Hello"}, ...]`
+  or `[%{role: "user", content: "Hello"}, ...]`
+  """
+  @spec chat(list(map()), keyword()) :: completion_result()
+  def chat(messages, opts \\ []) do
+    start_time = System.monotonic_time()
+    cache_key = if Keyword.get(opts, :cache, true), do: Cache.key({:chat, messages}, opts), else: nil
+
+    with :miss <- maybe_read_cache(cache_key),
+         {:ok, provider, model} <- select_provider_and_model(opts),
+         {:ok, result, metrics} <- execute_chat_with_fallback(provider, model, messages, opts) do
+
+      :ok = maybe_write_cache(cache_key, result)
+      track_metrics(metrics, provider, model, messages,