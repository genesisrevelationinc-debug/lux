```diff
--- /dev/null
+++ b/lux/lib/lux/llm/perplexity.ex
@@ -0,0 +1,218 @@
+defmodule Lux.LLM.Perplexity do
+  @moduledoc """
+  Perplexity AI integration for Lux.
+
+  Provides access to Perplexity AI's language models with support for:
+  - Streaming responses
+  - Model selection
+  - Cost tracking
+  - Error handling
+
+  ## Configuration
+
+  Configure the Perplexity client in your application config:
+
+      config :lux, :perplexity,
+        api_key: System.get_env("PERPLEXITY_API_KEY"),
+        base_url: "https://api.perplexity.ai",
+        default_model: "sonar",
+        timeout: 30_000
+
+  ## Usage
+
+      iex> alias Lux.LLM.Perplexity
+      iex> Perplexity.chat("What is the capital of France?")
+      {:ok, %{content: "The capital of France is Paris.", tokens: 10, cost: 0.0001}}
+
+      iex> Perplexity.chat("Explain quantum computing", stream: true)
+      {:ok, #Stream<[...]>}
+  """
+
+  alias Lux.LLM.Perplexity.CostTracker
+
+  @default_base_url "https://api.perplexity.ai"
+  @default_model "sonar"
+  @default_timeout 30_000
+
+  @valid_models [
+    "sonar",
+    "sonar-pro",
+    "sonar-reasoning",
+    "sonar-deep-research",
+    "sonar-reasoning-pro"
+  ]
+
+  @type message :: %{role: String.t(), content: String.t()}
+  @type chat_response :: %{
+          content: String.t(),
+          tokens: non_neg_integer(),
+          cost: float(),
+          model: String.t()
+        }
+  @type error :: {:error, String.t() | atom()}
+
+  @doc """
+  Sends a chat completion request to Perplexity AI.
+
+  ## Options
+
+  - `:model` - Model to use (default from config or "sonar")
+  - `:temperature` - Sampling temperature (0.0 to 2.0, default 0.7)
+  - `:max_tokens` - Maximum tokens in response (default 1024)
+  - `:stream` - Enable streaming (default false)
+  - `:system` - System message to prepend
+
+  ## Examples
+
+      iex> Perplexity.chat("Hello!")
+      {:ok, %{content: "Hello! How can I help you today?", tokens: 10, cost: 0.0001, model: "sonar"}}
+
+      iex> Perplexity.chat("Hello!", model: "sonar-pro", temperature: 0.5)
+      {:ok, %{content: "Hello! How can I help you today?", tokens: 10, cost: 0.0002, model: "sonar-pro"}}
+  """
+  @spec chat(String.t() | [message()], keyword()) ::
+          {:ok, chat_response()} | {:ok, Enumerable.t()} | error()
+  def chat(messages, opts \\ []) when is_binary(messages) or is_list(messages) do
+    messages = normalize_messages(messages)
+    model = opts[:model] || default_model()
+    stream? = Keyword.get(opts, :stream, false)
+
+    with :ok <- validate_model(model),
+         {:ok, request_body} <- build_request_body(messages, model, opts) do
+      if stream? do
+        stream_chat(request_body, model)
+      else
+        do_chat(request_body, model)
+      end
+    end
+  end
+
+  @doc """
+  Returns the list of available Perplexity models.
+  """
+  @spec available_models() :: [String.t()]
+  def available_models, do: @valid_models
+
+  @doc """
+  Validates if a model name is supported.
+  """
+  @spec valid_model?(String.t()) :: boolean()
+  def valid_model?(model) when is_binary(model) do
+    model in @valid_models
+  end
+
+  # Private functions
+
+  defp normalize_messages(text) when is_binary(text) do
+    [%{role: "user", content: text}]
+  end
+
+  defp normalize_messages(messages) when is_list(messages) do
+    Enum.map(messages, fn
+      %{role: _, content: _} = msg -> msg
+      %{content: _} = msg -> Map.put(msg, :role, "user")
+      text when is_binary(text) -> %{role: "user", content: text}
+    end)
+  end
+
+  defp validate_model(model) do
+    if valid_model?(model) do
+      :ok
+    else
+      {:error, "Invalid model: #{model}. Valid models: #{Enum.join(@valid_models, ", ")}"}
+    end
+  end
+
+  defp build_request_body(messages, model, opts) do
+    body = %{
+      model: model,
+      messages: messages,
+      temperature: opts[:temperature] || 0.7,
+      max_tokens: opts[:max_tokens] || 1024
+    }
+
+    body =
+      if system = opts[:system] do
+        Map.put(body, :system, system)
+      else
+        body
+      end
+
+    {:ok, body}
+  end
+
+  defp do_chat(body, model) do
+    case http_client().post(chat_url(), body, headers()) do
+      {:ok, %{status: 200, body: response}} ->
+        parse_response(response, model)
+
+      {:ok, %{status: status, body: response}} ->
+        {:error, "Perplexity API error (HTTP #{status}): #{inspect(response)}"}
+
+      {:error, reason} ->
+        {:error, "Request failed: #{inspect(reason)}"}
+    end
+  end
+
+  defp stream_chat(body, model) do
+    stream_body = Map.put(body, :stream, true)
+
+    stream =
+      Stream.resource(
+        fn -> stream_body end,
+        fn body ->
+          case http_client().post(chat_url(), body, headers(), stream: true) do
+            {:ok, %{status: 200, body: response}} ->
+              {[response], body}
+
+            {:ok, %{status: status, body: response}} ->
+              {[{:error, "Per