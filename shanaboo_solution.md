 ```diff
--- /dev/null
+++ b/lux/lib/lux/llm/perplexity.ex
@@ -0,0 +1,218 @@
+defmodule Lux.LLM.Perplexity do
+  @moduledoc """
+  Perplexity AI API integration for Lux.
+
+  Provides access to Perplexity's language models with support for:
+  - Streaming and non-streaming responses
+  - Model selection
+  - Cost tracking
+  - Error handling
+  """
+
+  require Logger
+
+  alias Lux.LLM.Perplexity.CostTracker
+
+  @default_base_url "https://api.perplexity.ai"
+  @api_version "2023-06-15"
+
+  # Available Perplexity models
+  @models %{
+    "sonar-small-chat" => %{name: "Sonar Small Chat", context_length: 16384},
+    "sonar-medium-chat" => %{name: "Sonar Medium Chat", context_length: 16384},
+    "sonar-large-chat" => %{name: "Sonar Large Chat", context_length: 16384},
+    "sonar-small-online" => %{name: "Sonar Small Online", context_length: 12000},
+    "sonar-medium-online" => %{name: "Sonar Medium Online", context_length: 12000},
+    "sonar-large-online" => %{name: "Sonar Large Online", context_length: 12000},
+    "codellama" => %{name: "CodeLlama", context_length: 16384},
+    "llama-2-70b-chat" => %{name: "Llama 2 70B Chat", context_length: 16384},
+    "mistral-7b-instruct" => %{name: "Mistral 7B Instruct", context_length: 16384},
+    "mixtral-8x7b-instruct" => %{name: "Mixtral 8x7B Instruct", context_length: 16384}
+  }
+
+  # Pricing per 1M tokens (input, output)
+  @pricing %{
+    "sonar-small-chat" => {0.20, 0.20},
+    "sonar-medium-chat" => {0.20, 0.20},
+    "sonar-large-chat" => {0.20, 0.20},
+    "sonar-small-online" => {0.20, 0.20},
+    "sonar-medium-online" => {0.20, 0.20},
+    "sonar-large-online" => {0.20, 0.20},
+    "codellama" => {0.20, 0.20},
+    "llama-2-70b-chat" => {0.70, 0.70},
+    "mistral-7b-instruct" => {0.20, 0.20},
+    "mixtral-8x7b-instruct" => {0.60, 0.60}
+  }
+
+  @type message :: %{role: String.t(), content: String.t()}
+  @type completion_response :: %{
+    id: String.t(),
+    model: String.t(),
+    content: String.t(),
+    usage: map(),
+    citations: list()
+  }
+  @type stream_chunk :: %{
+    id: String.t(),
+    model: String.t(),
+    delta: String.t(),
+    finish_reason: String.t() | nil
+  }
+
+  @doc """
+  Returns a list of available Perplexity models.
+  """
+  @spec list_models() :: list({String.t(), map()})
+  def list_models do
+    Map.to_list(@models)
+  end
+
+  @doc """
+  Returns model information for the given model ID.
+  """
+  @spec get_model(String.t()) :: {:ok, map()} | {:error, :unknown_model}
+  def get_model(model_id) do
+    case Map.get(@models, model_id) do
+      nil -> {:error, :unknown_model}
+      info -> {:ok, info}
+    end
+  end
+
+  @doc """
+  Validates if a model ID is supported.
+  """
+  @spec valid_model?(String.t()) :: boolean()
+  def valid_model?(model_id) do
+    Map.has_key?(@models, model_id)
+  end
+
+  @doc """
+  Calculates the estimated cost for a request based on token usage.
+  """
+  @spec estimate_cost(String.t(), integer(), integer()) :: {:ok, float()} | {:error, atom()}
+  def estimate_cost(model_id, input_tokens, output_tokens) do
+    case Map.get(@pricing, model_id) do
+      nil ->
+        {:error, :unknown_model}
+
+      {input_price, output_price} ->
+        cost = (input_tokens * input_price + output_tokens * output_price) / 1_000_000
+        {:ok, cost}
+    end
+  end
+
+  @doc """
+  Sends a completion request to the Perplexity API.
+  """
+  @spec completion(String.t(), list(message()), keyword()) ::
+          {:ok, completion_response()} | {:error, term()}
+  def completion(model_id, messages, opts \\ []) do
+    with :ok <- validate_model(model_id),
+         {:ok, body} <- build_request_body(model_id, messages, opts),
+         {:ok, response} <- do_request("/chat/completions", body, opts) do
+      parse_completion_response(response)
+    end
+  end
+
+  @doc """
+  Streams a completion request from the Perplexity API.
+  """
+  @spec stream_completion(String.t(), list(message()), keyword()) ::
+          {:ok, Enumerable.t()} | {:error, term()}
+  def stream_completion(model_id, messages, opts \\ []) do
+    with :ok <- validate_model(model_id),
+         {:ok, body} <- build_request_body(model_id, messages, Keyword.put(opts, :stream, true)) do
+      do_stream_request("/chat/completions", body, opts)
+    end
+  end
+
+  # Private functions
+
+  defp validate_model(model_id) do
+    if valid_model?(model_id) do
+      :ok
+    else
+      {:error, {:unknown_model, model_id}}
+    end
+  end
+
+  defp build_request_body(model_id, messages, opts) do
+    body = %{
+      model: model_id,
+      messages: messages,
+      max_tokens: Keyword.get(opts, :max_tokens, 1024