```diff
--- /dev/null
+++ b/lux/lib/lux/llm/perplexity.ex
@@ -0,0 +1,218 @@
+defmodule Lux.LLM.Perplexity do
+  @moduledoc """
+  Perplexity AI integration for Lux.
+
+  Provides access to Perplexity's language models with support for:
+  - Streaming and non-streaming responses
+  - Model selection
+  - Cost tracking
+  - Error handling
+
+  ## Configuration
+
+  Configure the Perplexity client in your config:
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
+      {:ok, %{content: "The capital of France is Paris.", citations: [...]}}
+
+  """
+
+  alias Lux.LLM.Perplexity.CostTracker
+
+  @default_base_url "https://api.perplexity.ai"
+  @default_model "sonar"
+  @default_timeout 30_000
+
+  @type message :: %{role: String.t(), content: String.t()}
+  @type chat_response :: %{
+          content: String.t(),
+          citations: list(String.t()),
+          model: String.t(),
+          usage: map()
+        }
+  @type stream_chunk :: %{
+          content: String.t(),
+          citations: list(String.t()),
+          done: boolean()
+        }
+
+  @doc """
+  Sends a chat completion request to Perplexity AI.
+
+  ## Options
+
+    * `:model` - The model to use (default: configured default or "sonar")
+    * `:messages` - List of messages for the conversation
+    * `:temperature` - Sampling temperature (0.0 to 1.0)
+    * `:max_tokens` - Maximum number of tokens to generate
+    * `:stream` - Whether to stream the response (default: false)
+    * `:return_citations` - Whether to return citations (default: true)
+
+  ## Examples
+
+      iex> Perplexity.chat("Hello!")
+      {:ok, %{content: "Hello! How can I help you today?", citations: [], model: "sonar", usage: %{}}}
+
+      iex> Perplexity.chat([%{role: "user", content: "Hello!"}])
+      {:ok, %{content: "Hello! How can I help you today?", citations: [], model: "sonar", usage: %{}}}
+
+  """
+  @spec chat(String.t() | list(message()), keyword()) ::
+          {:ok, chat_response()} | {:error, term()}
+  def chat(input, opts \\ []) do
+    messages = normalize_messages(input)
+    model = opts[:model] || default_model()
+    stream = Keyword.get(opts, :stream, false)
+
+    body = %{
+      model: model,
+      messages: messages,
+      stream: stream
+    }
+    |> maybe_add_temperature(opts)
+    |> maybe_add_max_tokens(opts)
+    |> maybe_add_return_citations(opts)
+
+    if stream do
+      stream_chat(body, opts)
+    else
+      do_chat(body, opts)
+    end
+  end
+
+  @doc """
+  Streams a chat completion from Perplexity AI.
+
+  Returns a stream of chunks that can be processed as they arrive.
+
+  ## Examples
+
+      iex> Perplexity.stream_chat("Tell me a story")
+      #Stream<[enum: #Function<...>, funs: [...]]>
+
+  """
+  @spec stream_chat(String.t() | list(message()), keyword()) :: Enumerable.t()
+  def stream_chat(input, opts \\ []) do
+    messages = normalize_messages(input)
+    model = opts[:model] || default_model()
+
+    body = %{
+      model: model,
+      messages: messages,
+      stream: true
+    }
+    |> maybe_add_temperature(opts)
+    |> maybe_add_max_tokens(opts)
+
+    request_stream(body, opts)
+  end
+
+  # Private functions
+
+  defp do_chat(body, opts) do
+    start_time = System.monotonic_time()
+
+    case http_client().post(chat_url(), body, headers(), request_opts()) do
+      {:ok, %{status: status, body: response_body}} when status in 200..299 ->
+        parsed = Jason.decode!(response_body)
+        content = get_in(parsed, ["choices", Access.at(0), "message", "content"]) || ""
+        citations = get_in(parsed, ["citations"]) || []
+        model = parsed["model"] || body.model
+        usage = parse_usage(parsed["usage"])
+
+        CostTracker.track_request(model, usage, :success)
+
+        result = %{
+          content: content,
+          citations: citations,
+          model: model,
+          usage: usage
+        }
+
+        {:ok, result}
+
+      {:ok, %{status: status, body: response_body}} ->
+        error = parse_error(status, response_body)
+        CostTracker.track_request(body[:model], %{}, :error)
+        {:error, error}
+
+      {:error, reason} ->
+        CostTracker.track_request(body[:model], %{}, :error)
+        {:error, %{type: :network_error, message: inspect(reason)}}
+    end
+  end
+
+  defp stream_chat(body, opts) do
+    request_stream(body, opts)
+  end
+
+  defp request_stream(body, opts) do
+    Stream.resource(
+      fn ->
+        {:ok, ref} = :hackney.post(
+          chat_url(),
+          headers(),
+          Jason.encode!(body),
+          [async: true, recv_timeout: @default_timeout]
+        )
+        ref
+      end,
+      fn ref ->
+        receive do
+          {:hackney_response, ^ref, {:status, status, _reason}} when status in 200..299 ->
+            {[], ref}
+
+          {:hackney_response, ^ref, {:status, status, _reason}} ->
+            {:halt, {:error, %{type: :http_error, status: status}}}
+
+          {:hackney_response, ^ref, {:headers, _headers}} ->
+            {[], ref}
+
+          {:hackney_response, ^ref, chunk} when is_binary(chunk) ->
+