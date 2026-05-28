```diff
--- /dev/null
+++ b/lux/lib/lux/llm/perplexity.ex
@@ -0,0 +1,296 @@
+defmodule Lux.LLM.Perplexity do
+  @moduledoc """
+  Perplexity AI API integration for Lux.
+
+  Provides access to Perplexity's language models with support for:
+  - Streaming responses
+  - Model selection
+  - Cost tracking
+  - Error handling
+
+  ## Configuration
+
+  Configure the Perplexity client in your application config:
+
+      config :lux, Lux.LLM.Perplexity,
+        api_key: System.get_env("PERPLEXITY_API_KEY"),
+        base_url: "https://api.perplexity.ai",
+        default_model: "llama-3.1-sonar-small-128k-online",
+        timeout: 30_000
+
+  ## Available Models
+
+  - `llama-3.1-sonar-small-128k-online` - Fast, cost-effective
+  - `llama-3.1-sonar-large-128k-online` - Balanced performance
+  - `llama-3.1-sonar-huge-128k-online` - Maximum capability
+  """
+
+  require Logger
+
+  alias Lux.LLM.Perplexity.CostTracker
+
+  @default_base_url "https://api.perplexity.ai"
+  @chat_endpoint "/chat/completions"
+
+  @default_config [
+    base_url: @default_base_url,
+    default_model: "llama-3.1-sonar-small-128k-online",
+    timeout: 30_000,
+    recv_timeout: 30_000
+  ]
+
+  @doc """
+  Returns the default configuration for the Perplexity client.
+  """
+  def default_config do
+    @default_config
+  end
+
+  @doc """
+  Gets the configured API key from application environment.
+  """
+  def api_key do
+    Application.get_env(:lux, __MODULE__, [])
+    |> Keyword.get(:api_key) ||
+      System.get_env("PERPLEXITY_API_KEY")
+  end
+
+  @doc """
+  Gets the base URL for the Perplexity API.
+  """
+  def base_url do
+    Application.get_env(:lux, __MODULE__, [])
+    |> Keyword.get(:base_url, @default_base_url)
+  end
+
+  @doc """
+  Gets the default model to use for requests.
+  """
+  def default_model do
+    Application.get_env(:lux, __MODULE__, [])
+    |> Keyword.get(:default_model, "llama-3.1-sonar-small-128k-online")
+  end
+
+  @doc """
+  Sends a chat completion request to Perplexity AI.
+
+  ## Options
+
+  - `:model` - Model to use (defaults to configured default)
+  - `:messages` - List of message maps with `:role` and `:content`
+  - `:temperature` - Sampling temperature (0.0 to 2.0)
+  - `:max_tokens` - Maximum tokens in response
+  - `:stream` - Whether to stream the response (default: false)
+  - `:callback` - Function to call with each stream chunk
+
+  ## Examples
+
+      iex> Perplexity.chat(
+      ...>   messages: [%{role: "user", content: "What is Elixir?"}]
+      ...> )
+      {:ok, %{choices: [%{message: %{content: "Elixir is..."}}]}}
+
+  """
+  def chat(opts \\ []) do
+    model = Keyword.get(opts, :model, default_model())
+    messages = Keyword.fetch!(opts, :messages)
+    temperature = Keyword.get(opts, :temperature, 0.7)
+    max_tokens = Keyword.get(opts, :max_tokens, 1024)
+    stream = Keyword.get(opts, :stream, false)
+    callback = Keyword.get(opts, :callback)
+
+    body = %{
+      model: model,
+      messages: messages,
+      temperature: temperature,
+      max_tokens: max_tokens,
+      stream: stream
+    }
+
+    if stream do
+      stream_chat(body, callback)
+    else
+      regular_chat(body)
+    end
+  end
+
+  @doc """
+  Streams a chat completion response from Perplexity AI.
+
+  Each chunk is passed to the provided callback function.
+
+  ## Options
+
+  Same as `chat/1` but `:stream` is automatically set to `true`.
+
+  ## Examples
+
+      iex> Perplexity.stream_chat(
+      ...>   messages: [%{role: "user", content: "Tell me a story"}],
+      ...>   callback: fn chunk -> IO.puts(chunk) end
+      ...> )
+      :ok
+
+  """
+  def stream_chat(body, callback) do
+    body = Map.put(body, :stream, true)
+
+    headers = [
+      {"Authorization", "Bearer #{api_key()}"},
+      {"Content-Type", "application/json"},
+      {"Accept", "text/event-stream"}
+    ]
+
+    url = base_url() <> @chat_endpoint
+
+    start_time = System.monotonic_time(:millisecond)
+
+    case HTTPoison.post(url, Jason.encode!(body), headers, stream_to: self(), async: true) do
+      {:ok, %HTTPoison.AsyncResponse{id: _id}} ->
+        result = handle_stream(callback)
+        end_time = System.monotonic_time(:millisecond)
+        CostTracker.track_request(body[:model], 0, end_time - start_time)
+        result
+
+      {:error, %HTTPoison.Error{reason: reason}} ->
+        {:error, {:request_failed, reason}}
+    end
+  end
+
+  defp regular_chat(body) do
+    headers = [
+      {"Authorization", "Bearer #{api_key()}"},
+      {"Content-Type", "application/json"}
+    ]
+
+    url = base_url() <> @chat_endpoint
+
+    start_time = System.monotonic_time(:millisecond)
+
+    case HTTPoison.post(url, Jason.encode!(body), headers) do
+      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
+        end_time = System.monotonic_time(:millisecond)
+
+        with {:ok, parsed} <- Jason.decode(response_body) do
+          CostTracker.track_request(
+            body[:model],
+            get_in(parsed, ["usage", "total_tokens"]) ||