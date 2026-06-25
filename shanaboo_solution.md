 ```diff
--- /dev/null
+++ b/lux/lib/lux/llm/perplexity.ex
@@ -0,0 +1,234 @@
+defmodule Lux.LLM.Perplexity do
+  @moduledoc """
+  Perplexity AI API integration for Lux.
+
+  Provides access to Perplexity's language models with support for:
+  - Streaming and non-streaming responses
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
+        default_model: "sonar",
+        base_url: "https://api.perplexity.ai"
+
+  ## Usage
+
+      iex> alias Lux.LLM.Perplexity
+      iex> Perplexity.chat_completion([%{role: "user", content: "Hello!"}])
+      {:ok, %{choices: [%{message: %{content: "Hello!"}}]}}
+
+  """
+
+  alias Lux.LLM.Perplexity.CostTracker
+
+  @default_base_url "https://api.perplexity.ai"
+  @default_model "sonar"
+
+  @valid_models [
+    "sonar",
+    "sonar-pro",
+    "sonar-reasoning",
+    "sonar-deep-research",
+    "sonar-reasoning-pro"
+  ]
+
+  @type message :: %{
+          role: String.t(),
+          content: String.t()
+        }
+
+  @type chat_completion_opts :: %{
+          optional(:model) => String.t(),
+          optional(:temperature) => float(),
+          optional(:max_tokens) => integer(),
+          optional(:top_p) => float(),
+          optional(:stream) => boolean(),
+          optional(:presence_penalty) => float(),
+          optional(:frequency_penalty) => float()
+        }
+
+  @doc """
+  Returns the list of valid Perplexity models.
+  """
+  @spec valid_models() :: [String.t()]
+  def valid_models, do: @valid_models
+
+  @doc """
+  Sends a chat completion request to the Perplexity API.
+
+  ## Options
+
+  - `:model` - The model to use (default: "sonar")
+  - `:temperature` - Sampling temperature (default: 0.7)
+  - `:max_tokens` - Maximum tokens in response (default: 1024)
+  - `:top_p` - Nucleus sampling parameter (default: 0.9)
+  - `:stream` - Whether to stream the response (default: false)
+  - `:presence_penalty` - Presence penalty (default: 0.0)
+  - `:frequency_penalty` - Frequency penalty (default: 0.0)
+
+  ## Examples
+
+      iex> Perplexity.chat_completion([%{role: "user", content: "What is Elixir?"}])
+      {:ok, %{choices: [%{message: %{content: "Elixir is a functional programming language..."}}]}}
+
+  """
+  @spec chat_completion([message()], chat_completion_opts()) ::
+          {:ok, map()} | {:error, term()}
+  def chat_completion(messages, opts \\ %{}) do
+    model = Map.get(opts, :model, default_model())
+    stream = Map.get(opts, :stream, false)
+
+    unless model in @valid_models do
+      return_error(:invalid_model, "Invalid model: #{model}. Valid models: #{Enum.join(@valid_models, ", ")}")
+    end
+
+    body =
+      %{
+        model: model,
+        messages: messages,
+        stream: stream
+      }
+      |> add_optional_params(opts)
+
+    if stream do
+      stream_chat_completion(body, opts)
+    else
+      do_chat_completion(body, opts)
+    end
+  end
+
+  @doc """
+  Streams a chat completion response from the Perplexity API.
+
+  Returns a stream of response chunks that can be consumed with `Enum` or `Stream`.
+
+  ## Examples
+
+      iex> Perplexity.stream_chat_completion([%{role: "user", content: "Tell me a story"}])
+      iex> |> Enum.to_list()
+      [%{choices: [%{delta: %{content: "Once"}}]}, ...]
+
+  """
+  @spec stream_chat_completion([message()], chat_completion_opts()) ::
+          Enumerable.t() | {:error, term()}
+  def stream_chat_completion(messages, opts \\ %{}) do
+    opts = Map.put(opts, :stream, true)
+    chat_completion(messages, opts)
+  end
+
+  # Private functions
+
+  defp do_chat_completion(body, opts) do
+    url = "#{base_url()}/chat/completions"
+
+    headers = [
+      {"Authorization", "Bearer #{api_key()}"},
+      {"Content-Type", "application/json"}
+    ]
+
+    case HTTPoison.post(url, Jason.encode!(body), headers, recv_timeout: 60_000) do
+      {:ok, %{status_code: 200, body: response_body}} ->
+        case Jason.decode(response_body) do
+          {:ok, response} ->
+            track_cost(response, opts)
+            {:ok, response}
+
+          {:error, reason} ->
+            return_error(:json_decode_error, "Failed to decode response: #{inspect(reason)}")
+        end
+
+      {:ok, %{status_code: status_code, body: response_body}} ->
+        handle_http_error(status_code, response_body)
+
+      {:error, %{reason: reason}} ->
+        return_error(:request_failed, "HTTP request failed: #{inspect(reason)}")
+    end
+  end
+
+  defp stream_chat_completion(body, opts) do
+    url = "#{base_url()}/chat/completions"
+
+    headers = [
+      {"Authorization", "Bearer #{api_key()}"},
+      {"Content-Type", "application/json"},
+      {"Accept", "text/event-stream"}
+    ]
+
+    Stream.resource(
+      fn ->
+        case HTTPoison.post(url, Jason.encode!(body), headers,
+               stream_to: self(),
+               async: :once,
+               recv_timeout: 60_000
+             ) do
+          {:ok, %HTTPoison.AsyncResponse{id: id}} -> id
+          {:error, reason} -> throw({:error, reason})
+        end
+      end,
+      fn id ->
+        receive do
+          %HTTPo