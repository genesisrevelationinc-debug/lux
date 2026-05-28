Looking at this issue, I need to implement a Perplexity AI integration for the Lux framework. This is an multi-agent framework written in Elixir. Let me analyze the structure and create the necessary files.

Based on the issue requirements and the Elixir project structure, I need to:
1. Create a Perplexity API client
2. Add streaming support
3. Create model selection interface
4. Implement error handling
5. Add cost tracking
6. Include documentation
7. Add integration tests

Let me infer the structure from the repo. This appears to be an main `lux` directory with the core library. I'll create the Perplexity integration following Elixir conventions.

```diff
--- /dev/null
+++ b/lux/lib/lux/llm/perplexity.ex
@@ -0,0 +1,334 @@
+defmodule Lux.LLM.Perplexity do
+  @moduledoc """
+  Perplexity AI API client for advanced language model capabilities.
+
+  Provides integration with Perplexity's API for knowledge-intensive tasks,
+  with support for streaming responses, model selection, and cost tracking.
+
+  ## Configuration
+
+  Configure the client in your application config:
+
+      config :lux, :perplexity,
+        api_key: System.get_env("PERPLEXITY_API_KEY"),
+        base_url: "https://api.perplexity.ai",
+        default_model: "llama-3.1-sonar-large-128k-online",
+        timeout: 30_000
+
+  ## Usage
+
+      iex> alias Lux.LLM.Perplexity
+      iex> Perplexity.chat_completion([
+      ...>   %{role: "user", content: "What is quantum computing?"}
+      ...> ])
+      {:ok, %Perplexity.Response{}}
+
+  """
+
+  alias Lux.LLM.Perplexity.{Config, Response, Error, CostTracker}
+
+  require Logger
+
+  @default_base_url "https://api.perplexity.ai"
+  @chat_completions_path "/chat/completions"
+
+  @valid_models [
+    "llama-3.1-sonar-large-128k-online",
+    "llama-3.1-sonar-small-128k-online",
+    "llama-3.1-sonar-pro-128k-online",
+    "llama-3.1-sonar-reasoning-pro-128k-online",
+    "llama-3.1-sonar-reasoning-128k-online",
+    "llama-3.1-sonar-deep-research",
+    "sonar",
+    "sonar-pro",
+    "sonar-reasoning",
+    "sonar-reasoning-pro",
+    "sonar-deep-research"
+  ]
+
+  @doc """
+  Returns the list of valid Perplexity models.
+  """
+  @spec valid_models() :: [String.t()]
+  def valid_models, do: @valid_models
+
+  @doc """
+  Checks if a model name is valid.
+  """
+  @spec valid_model?(String.t()) :: boolean()
+  def valid_model?(model) when is_binary(model) do
+    model in @valid_models
+  end
+
+  def valid_model?(_), do: false
+
+  @doc """
+  Sends a chat completion request to the Perplexity API.
+
+  ## Options
+
+    * `:model` - The model to use (default from config or `llama-3.1-sonar-large-128k-online`)
+    * `:temperature` - Sampling temperature (default: 0.2)
+    * `:max_tokens` - Maximum tokens to generate (default: 1024)
+    * `:top_p` - Nucleus sampling parameter (default: 0.9)
+    * `:stream` - Whether to stream the response (default: false)
+    * `:return_images` - Whether to return images (default: false)
+    * `:return_related_questions` - Whether to return related questions (default: false)
+    * `:search_recency_filter` - Filter search results by recency (e.g., "month", "week", "day")
+
+  ## Examples
+
+      iex> Perplexity.chat_completion([
+      ...>   %{role: "system", content: "You are a helpful assistant."},
+      ...>   %{role: "user", content: "Explain quantum computing"}
+      ...> ], model: "llama-3.1-sonar-large-128k-online", temperature: 0.5)
+
+  """
+  @type message :: %{required(:role) => String.t(), required(:content) => String.t()}
+  @type chat_options :: [
+          model: String.t(),
+          temperature: float(),
+          max_tokens: integer(),
+          top_p: float(),
+          stream: boolean(),
+          return_images: boolean(),
+          return_related_questions: boolean(),
+          search_recency_filter: String.t(),
+          callback: (any() -> any())
+        ]
+
+  @spec chat_completion([message()], chat_options()) ::
+          {:ok, Response.t()} | {:error, Error.t()}
+  def chat_completion(messages, opts \\ []) when is_list(messages) do
+    config = Config.get()
+
+    with :ok <- validate_messages(messages),
+         :ok <- validate_config(config),
+         model <- get_model(opts, config),
+         :ok <- validate_model(model) do
+      body = build_request_body(messages, model, opts)
+
+      if Keyword.get(opts, :stream, false) do
+        stream_request(body, config, opts)
+      else
+        synchronous_request(body, config, opts)
+      end
+    end
+  end
+
+  @doc """
+  Streams a chat completion response from the Perplexity API.
+
+  The callback function will be called with each chunk of the response.
+
+  ## Examples
+
+      iex> Perplexity.stream_chat_completion([
+      ...>   %{role: "user", content: "Tell me a story"}
+      ...> ], fn chunk ->
+      ...>   IO.puts(chunk.choices |> List.first() |> Map.get(:delta, %{}) |> Map.get(:content, ""))
+      ...> end)
+
+  """
+  @spec stream_chat_completion([message()], (any() -> any()), chat_options()) ::
+          {:ok, Response.t()} | {:error, Error.t()}
+  def stream_chat_completion(messages, callback, opts \\ []) when is_function(callback, 1) do
+    chat_completion(messages, Keyword.put(opts, :stream, true) |> Keyword.put(:callback, callback))
+  end
+
+  # Private functions
+
