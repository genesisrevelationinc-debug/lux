 ```diff
--- a/lux/lib/lux/llm/perplexity.ex
+++ anonymous
@@ -0,0 +1,268 @@
+defmodule Lux.LLM.perplexity do
+  @moduledoc """
+  Perplexity AI API client for Lux.
+
+  Provides integration with Perplexity AI's API for advanced language model
+  capabilities, including streaming support, model selection, and cost tracking.
+
+  ## Configuration
+
+  Configure the Perplexity client in your application config:
+
+      config :lux, Lux.LLM.Perplexity,
+        api_key: System.get_env("PERPLEXITY_API_KEY"),
+        base_url: "https://api.perplexity.ai",
+        default_model: "llama-3.1-sonar-large-128k-online",
+        timeout: 30_000
+
+  ## Usage
+
+      iex> alias Lux.LLM.Perplexity
+      iex> Perplexity.chat("What is the capital of France?")
+      {:ok, %{"choices" => [%{"message" => %{"content" => "The capital of France is Paris."}}]}}
+
+  """
+
+  alias Lux.LLM.Perplexity.CostTracker
+
+  @default_base_url "https://api.perplexity.ai"
+  @default_model "llama-3.1-sonar-large-128k-online"
+  @default_timeout 30_000
+
+  @available_models [
 |>  "llama-3.1-sonar-small-128k-online",
+    "llama-3.1-sonar-large-128k-online",
+    "llama-3.1-sonar-huge-128k-online",
+    "llama-3.1-70b-instruct",
+    "llama-3.1-8b-instruct",
+    "mixtral-8x7b-instruct",
+    "codellama-70b-instruct"
+  ]
+
+  @doc """
+  Returns the list of available Perplexity models.
+  """
+  @spec available_models() :: [String.t()]
+  def available_models, do: @available_models
+
+  @doc """
+  Sends a chat completion request to Perplexity AI.
+
+  ## Options
+
+    * `:model` - The model to use (default from config or `#{@default_model}`)
+    * `:messages` - List of message maps with `role` and `content`
+    * `:temperature` - Sampling temperature (0.0 to 2.0)
+    * `:max_tokens` - Maximum tokens to generate
+    * `:stream` - Whether to stream the response (default: false)
+    * `:callback` - Function to call with each streamed chunk
+
+  ## Examples
+
+      iex> Perplexity.chat([%{role: "user", content: "Hello!"}])
+      {:ok, %{"choices" => [...]}}
+
+      iex> Perplexity.chat([%{role: "user", content: "Hello!"}], stream: true, callback: &IO.inspect/1)
+      {:ok, %Lux.LLM.Perplexity.Stream{}}
+
+  """
+  @spec chat([map()], keyword()) :: {:ok, map()} | {:error, term()}
+  def chat(messages, opts \\ []) do
+    model = opts[:model] || default_model()
+    stream = Keyword.get(opts, :stream, false)
+
+    body = %{
+      model: model,
+      messages: messages,
+      temperature: opts[:temperature] || 0.7,
+      max_tokens: opts[:max_tokens] || 2048
+    }
+
+    body =
+      if stream do
+        Map.put(body, :stream, true)
+      else
+        body
+      end
+
+    if stream do
+      do_stream_request(body, opts)
+    else
+      do_request(body, opts)
+    end
+  end
+
+  @doc """
+  Sends a simple text prompt to Perplexity AI.
+
+  ## Examples
+
+      iex> Perplexity.chat("What is the capital of France?")
+      {:ok, %{"choices" => [%{"message" => %{"content" => "Paris"}}]}}
+
+  """
+  @spec chat(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
+  def chat(prompt, opts) when is_binary(prompt) do
+    messages = [%{role: "user", content: prompt}]
+    chat(messages, opts)
+  end
+
+  @doc """
+  Streams a chat completion from Perplexity AI.
+
+  Returns a stream that can be consumed with `Enum` or `Stream` functions.
+
+  ## Examples
+
+      iex> Perplexity.stream_chat([%{role: "user", content: "Tell me a story"}])
+      {:ok, %Stream{}}
+
+  """
+  @spec stream_chat([map()], keyword()) :: {:ok, Enumerable.t()} | {:error, term()}
+  def stream_chat(messages, opts \\ []) do
+    opts = Keyword.put(opts, :stream, true)
+    chat(messages, opts)
+  end
+
+  # Private functions
+
+  defp do_request(body, opts) do
+    url = "#{base_url()}/chat/completions"
+    headers = default_headers()
+
+    start_time = System.monotonic_time()
+
+    case HTTPoison.post(url, Jason.encode!(body), headers, request_opts()) do
+      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
+        case Jason.decode(response_body) do
+          {:ok, response} ->
+            track_cost(response, body,, start_time)
+            {:ok, response}
+
+          {:error, error} ->
+            {:error, {:json_decode_error, error}}
+        end
+
+      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
+        handle_error_response(status_code, response_body)
+
+      {:error, %HTTPoison.Error{reason: reason}} ->
+        {:error, {:request_failed, reason}}
+    end
+  end
+
+  defp do_stream_request(body, opts) do
+    callback = opts[:callback] || fn _ -> :ok end
+    url = "#{base_url()}/chat/completions"
+    headers = default_headers()
+
+    start_time = System.monotonic_time()
+
+    stream_ref =
+      HTTPoison.post!(url, Jason.encode!(body), headers, [
+        {:stream_to, self()},
+        {:async,