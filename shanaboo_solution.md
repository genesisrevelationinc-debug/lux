 ```diff
--- a/lux/lib/lux/llm/open_router.ex
+++ b/lux/llm/open_router.ex
@@ -0,0 +1,218 @@
+defmodule Lux.LLM.OpenRouter do
+  @moduledoc """
+  OpenRouter API client providing unified access to multiple LLM models.
+  
+  OpenRouter (https://openrouter.ai) provides a unified API for accessing
+  models from OpenAI, Anthropic, Google, Meta, and many other providers.
+  """
+  
+  alias Lux.LLM.OpenRouter.Config
+  alias Lux.LLM.OpenRouter.RateLimiter
+  alias Lux.LLM.OpenRouter.CostTracker
+  
+  require Logger
+  
+  @default_endpoint "https://openrouter.ai/api/v1/chat/completions"
+  @default_model "openrouter/auto"
+  
+  @type message :: %{role: String.t(), content: String.t()}
+  @type completion_opts :: [
+    model: String.t(),
+    temperature: float(),
+    max_tokens: integer(),
+    top_p: float(),
+    stream: boolean(),
+    tools: list(),
+    tool_choice: map() | String.t(),
+    response_format: map()
+  ]
+  
+  @doc """
+  Creates a chat completion using the OpenRouter API.
+  
+  ## Options
+  
+    * `:model` - The model to use (defaults to "openrouter/auto")
+    * `:temperature` - Sampling temperature (0.0 to 2.0)
+    * `:max_tokens` - Maximum tokens to generate
+    * `:top_p` - Nucleus sampling parameter
+    * `:stream` - Whether to stream the response
+    * `:tools` - List of available tools/functions
+    * `:tool_choice` - Tool selection strategy
+    * `:response_format` - Expected response format
+  
+  ## Examples
+  
+      iex> OpenRouter.chat_completion([
+      ...>   %{role: "user", content: "Hello!"}
+      ...> ], model: "anthropic/claude-3.5-sonnet")
+      {:ok, %{choices: [%{message: %{content: "Hello!"}}]}}
+  """
+  @spec chat_completion(list(message()), keyword()) ::
+          {:ok, map()} | {:error, term()}
+  def chat_completion(messages, opts \\ []) do
+    config = Config.load()
+    model = Keyword.get(opts, :model, config.default_model || @default_model)
+    
+    with :ok <- RateLimiter.check_limit(model),
+         {:ok, response} <- do_request(messages, opts, config) do
+      CostTracker.track(response, model)
+      {:ok, response}
+    end
+  end
+  
+  @doc """
+  Creates a streaming chat completion.
+  
+  Returns a stream of completion chunks.
+  """
+  @spec stream_chat_completion(list(message()), keyword()) ::
+          Enumerable.t() | {:error, term()}
+  def stream_chat_completion(messages, opts \\ []) do
+    config = Config.load()
+    opts = Keyword.put(opts, :stream, true)
+    
+    with :ok <- RateLimiter.check_limit(Keyword.get(opts, :model, @default_model)) do
+      do_stream_request(messages, opts, config)
+    end
+  end
+  
+  @doc """
+  Lists available models from OpenRouter.
+  """
+  @spec list_models() :: {:ok, list(map())} | {:error, term()}
+  def list_models do
+    config = Config.load()
+    
+    headers = [
+      {"Authorization", "Bearer #{config.api_key}"},
+      {"HTTP-Referer", config.http_referer || "https://github.com/Spectral-Finance/lux"},
+      {"X-Title", config.app_title || "Lux"}
+    ]
+    
+    case Req.get("https://openrouter.ai/api/v1/models", headers: headers) do
+      {:ok, %{status: 200, body: %{"data" => models}}} ->
+        {:ok, models}
+        
+      {:ok, %{status: status, body: body}} ->
+        Logger.error("OpenRouter list_models failed: HTTP #{status}, #{inspect(body)}")
+        {:error, {:http_error, status, body}}
+        
+      {:error, reason} ->
+        Logger.error("OpenRouter list_models request failed: #{inspect(reason)}")
+        {:error, reason}
+    end
+  end
+  
+  ## Private Functions
+  
+  defp do_request(messages, opts, config) do
+    body = build_request_body(messages, opts, config)
+    headers = build_headers(config)
+    
+    case Req.post(config.endpoint || @default_endpoint, headers: headers, json: body) do
+      {:ok, %{status: 200, body: response_body}} ->
+        {:ok, response_body}
+        
+      {:ok, %{status: status, body: body}} ->
+        Logger.error("OpenRouter request failed: HTTP #{status}, #{inspect(body)}")
+        {:error, {:http_error, status, body}}
+        
+      {:error, reason} ->
+        Logger.error("OpenRouter request failed: #{inspect(reason)}")
+        {:error, reason}
+    end
+  end
+  
+  defp do_stream_request(messages, opts, config) do
+    body = build_request_body(messages, opts, config)
+    headers = build_headers(config)
+    
+    Req.post!(config.endpoint || @default_endpoint,
+      headers: headers,
+      json: body,
+      into: :self
+    )
+    |> case do
+      %{status: 200, body: stream} ->
+        stream
+        |> Stream.transform("", fn chunk, acc ->
+          data = acc <> chunk
+          {lines, rest} = extract_lines(data)
+          {Enum.map(lines, &parse_sse_line/1), rest}
+        end)
+        
+      %{status: status, body: body} ->
+        Logger.error("OpenRouter stream failed: HTTP #{status}, #{inspect(body)}")
+        {:error, {:http_error, status, body}}
+    end
+  end
+  
+  defp build_request_body(messages, opts, _config) do
+    %{
+      model: Keyword.get(opts, :model, @default_model),
+      messages: messages,
+      temperature: Keyword.get(opts, :temperature, 0.7),
+      max_tokens: Keyword.get(opts, :max_tokens, 4096),
+      top_p: Keyword.get(opts, :top_p, 1.0),
+      stream: Keyword.get(opts, :stream, false)
+    }
+