```diff
--- a/lux/lib/lux/llm/ollama.ex
+++ b/lux/lib/lux/llm/ollama.ex
@@ -0,0 +1,312 @@
+defmodule Lux.LLM.Ollama do
+  @moduledoc """
+  Ollama LLM integration for local model support.
+
+  Provides a client for interacting with Ollama's API to run
+  local LLMs with support for chat completions, embeddings,
+  and model management.
+  """
+
+  alias Lux.Config
+
+  require Logger
+
+  @default_base_url "http://localhost:11434"
+  @default_timeout 300_000
+  @default_model "llama3.2"
+
+  @type t :: %__MODULE__{
+          base_url: String.t(),
+          model: String.t(),
+          timeout: non_neg_integer(),
+          temperature: float() | nil,
+          max_tokens: non_neg_integer() | nil,
+          top_p: float() | nil,
+          top_k: non_neg_integer() | nil,
+          seed: non_neg_integer() | nil,
+          system: String.t() | nil,
+          format: map() | nil,
+          http_client: module()
+        }
+
+  defstruct [
+    :base_url,
+    :model,
+    :timeout,
+    :temperature,
+    :max_tokens,
+    :top_p,
+    :top_k,
+    :seed,
+    :system,
+    :format,
+    :http_client
+  ]
+
+  @doc """
+  Creates a new Ollama client configuration.
+
+  ## Options
+
+  - `:base_url` - Ollama API base URL (default: `#{@default_base_url}`)
+  - `:model` - Model name to use (default: `#{@default_model}`)
+  - `:timeout` - Request timeout in milliseconds (default: `#{@default_timeout}`)
+  - `:temperature` - Sampling temperature
+  - `:max_tokens` - Maximum tokens to generate
+  - `:top_p` - Nucleus sampling parameter
+  - `:top_k` - Top-k sampling parameter
+  - `:seed` - Random seed for reproducibility
+  - `:system` - System prompt
+  - `:format` - Response format (e.g., `%{type: "json"}`)
+  - `:http_client` - HTTP client module (default: `Req`)
+
+  ## Examples
+
+      iex> Lux.LLM.Ollama.new(model: "llama3.2")
+      %Lux.LLM.Ollama{model: "llama3.2", base_url: "http://localhost:11434", ...}
+  """
+  @spec new(keyword()) :: t()
+  def new(opts \\ []) do
+    %__MODULE__{
+      base_url: opts[:base_url] || default_base_url(),
+      model: opts[:model] || @default_model,
+      timeout: opts[:timeout] || @default_timeout,
+      temperature: opts[:temperature],
+      max_tokens: opts[:max_tokens],
+      top_p: opts[:top_p],
+      top_k: opts[:top_k],
+      seed: opts[:seed],
+      system: opts[:system],
+      format: opts[:format],
+      http_client: opts[:http_client] || Req
+    }
+  end
+
+  @doc """
+  Generates a chat completion using the Ollama API.
+
+  ## Parameters
+
+  - `client` - Ollama client configuration
+  - `messages` - List of message maps with `:role` and `:content` keys
+  - `opts` - Additional options to override client settings
+
+  ## Examples
+
+      iex> client = Lux.LLM.Ollama.new(model: "llama3.2")
+      iex> messages = [%{role: "user", content: "Hello!"}]
+      iex> Lux.LLM.Ollama.chat(client, messages)
+      {:ok, %{message: %{role: "assistant", content: "Hello! How can I help?"}, ...}}
+  """
+  @spec chat(t(), list(map()), keyword()) ::
+          {:ok, map()} | {:error, String.t()} | {:error, non_neg_integer(), String.t()}
+  def chat(client, messages, opts \\ []) do
+    url = "#{client.base_url}/api/chat"
+
+    body =
+      %{
+        model: opts[:model] || client.model,
+        messages: messages,
+        stream: false
+      }
+      |> maybe_put(:temperature, opts[:temperature] || client.temperature)
+      |> maybe_put(:num_predict, opts[:max_tokens] || client.max_tokens)
+      |> maybe_put(:top_p, opts[:top_p] || client.top_p)
+      |> maybe_put(:top_k, opts[:top_k] || client.top_k)
+      |> maybe_put(:seed, opts[:seed] || client.seed)
+      |> maybe_put(:system, opts[:system] || client.system)
+      |> maybe_put(:format, opts[:format] || client.format)
+
+    case request(client, :post, url, json: body) do
+      {:ok, %{status: 200, body: body}} ->
+        {:ok, body}
+
+      {:ok, %{status: status, body: body}} when is_map(body) ->
+        {:error, status, body["error"] || "Unknown error"}
+
+      {:ok, %{status: status, body: body}} ->
+        {:error, status, to_string(body)}
+
+      {:error, reason} ->
+        {:error, inspect(reason)}
+    end
+  end
+
+  @doc """
+  Generates embeddings for the given text using Ollama.
+
+  ## Parameters
+
+  - `client` - Ollama client configuration
+  - `input` - Text or list of texts to embed
+  - `opts` - Additional options
+
+  ## Examples
+
+      iex> client = Lux.LLM.Ollama.new(model: "nomic-embed-text")
+      iex> Lux.LLM.Ollama.embeddings(client, "Hello world")
+      {:ok, %{embeddings: [[0.1, 0.2, ...]]}}
+  """
+  @spec embeddings(t(), String.t() | list(String.t()), keyword()) ::
+          {:ok, map()} | {:error, String.t()} | {:error, non_neg_integer(), String.t()}
+  def embeddings(client, input, opts \\ []) do
+    url = "#{client.base_url}/api/embed"
+
+    inputs = if is_list(input