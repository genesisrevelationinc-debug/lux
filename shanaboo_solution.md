 ```diff
--- /dev/null
+++ b/lux/lib/lux/llm/perplexity.ex
@@ -0,0 +1,287 @@
+defmodule Lux.LLM.Perplexity do
+  @moduledoc """
+  Perplexity AI integration for Lux.
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
+ safer- `llama-3.1-sonar-pro-128k-online` - Professional tasks
+  """
+
+  alias Lux.LLM.Perplexity.{Client, Response, StreamHandler}
+
+  require Logger
+
+  @default_models [
+    "llama-3.1-sonar-small-128k-online",
+    "llama-3.1-sonar-large-128k-online",
+    "llama-3.1-sonar-huge-128k-online",
+    "llama-3.1-sonar-pro-128k-online"
+  ]
+
+  @doc """
+  Returns the list of available Perplexity models.
+  """
+  def available_models, do: @default_models
+
+  @doc """
+  Sends a chat completion request to Perplexity AI.
+
+  ## Options
+
+    * `:model` - Model to use (defaults to config or first available model)
+    * `:messages` - List of messages with `:role` and `:content`
+    * `:temperature` - Sampling temperature (0.0 to 1.0)
+    * `:max_tokens` - Maximum tokens to generate
+    * `:stream` - Enable streaming (default: false)
+    * `:callback` - Function to call with stream chunks when streaming
+
+  ## Examples
+
+      iex> Perplexity.chat(
+      ...>   messages: [
+      ...>     %{role: "system", content: "You are a helpful assistant."},
+      ...>     %{role: "user", content: "What is quantum computing?"}
+      ...>   ]
+      ...> )
+      {:ok, %Response{}}
+
+      iex> Perplexity.chat(
+      ...>   messages: [%{role: "user", content: "Hello"}],
+      ...>   stream: true,
+      ...>   callback: fn chunk -> IO.inspect(chunk) end
+      ...> )
+      {:ok, %Response{}}
+  """
+  def chat(opts \\ []) do
+    messages = Keyword.get(opts, :messages, [])
+    model = Keyword.get(opts, :model, default_model())
+    temperature = Keyword.get(opts, :temperature, 0.7)
+    max_tokens = Keyword.get(opts, :max_tokens20_000)
+    stream = Keyword.get(opts, :stream, false)
+    callback = Keyword.get(opts, :callback)
+
+    request_body = %{
+      model: model,
+      messages: messages,
+      temperature: temperature,
+      max_tokens: max_tokens,
+      stream: stream
+    }
+    |> maybe_add_top_p(opts)
+    |> maybe_add_presence_penalty(opts)
+    |> maybe_add_frequency_penalty(opts)
+
+    if stream do
+      stream_chat(request_body, callback)
+    else
+      Client.request(:post, "/chat/completions", request_body)
+      |> handle_response()
+    end
+  end
+
+  @doc """
+  Sends a streaming chat completion request to Perplexity AI.
+
+  This is a convenience function that sets `stream: true` automatically.
+
+  ## Options
+
+  Same as `chat/1` but with streaming enabled by default.
+
+  ## Examples
+
+      iex> Perplexity.stream_chat(
+      ...>   messages: [%{role: "user", content: "Tell me a story"}],
+      ...>   callback: fn chunk -> IO.puts(chunk.content) end
+      ...> )
+      {:ok, %Response{}}
+  """
+  def stream_chat(opts \\ []) do
+    callback = Keyword.get(opts, :callback) || raise ArgumentError, "callback is required for streaming"
+
+    request_body = opts
+    |> Keyword.put(:stream, true)
+    |> build_request_body()
+
+    Client.stream_request(:post, "/chat/completions", request_body, callback)
+    |> handle_response()
+  end
+
+  @doc """
+  Returns the estimated cost for a request based on model and token count.
+
+  ## Examples
+
+      iex> Perplexity.estimate_cost("llama-3.1-sonar-small-128k-online", 1000, 500)
+      %{input_cost: 0.0002, output_cost: 0.0004, total_cost: 0.0006}
+  """
+  def estimate_cost(model, input_tokens, output_tokens) do
+    pricing = get_pricing(model)
+
+    input_cost = input_tokens * pricing.input_price_per_token
+    output_cost = output_tokens * pricing.output_price_per_token
+    total_cost = input_cost + output_cost
+
+    %{
+      input_cost: input_cost,
+      output_cost: output_cost,
+      total_cost: total_cost,
+      currency: "USD"
+    }
+  end
+
+  @doc """
+  Validates if a model name is supported.
+  """
+  def valid_model?(model) when is_binary(model) do
+    model in @default_models
+  end
+
+  def valid_model?(_), do: false
+
+  # Private functions
+
+  defp default_model do
+    Application.get_env(:lux, __MODULE__, [])
+    |> Keyword.get(:default_model, hd(@default_models))
+  end
+
+  defp maybe_add_top_p(body, opts) do
+    case Keyword.get(opts, :top_p) do
+      nil