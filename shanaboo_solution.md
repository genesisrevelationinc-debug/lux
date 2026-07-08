 ```diff
--- /dev/null
+++ b/lux/lib/lux/llm/ollama.ex
@@ -0,0 +1,268 @@
+defmodule Lux.LLM.Ollama do
+  @moduledoc """
+  Ollama client for local LLM support.
+
+  Provides integration with Ollama's API for running local models,
+  with support for model management, caching, and resource controls.
+  """
+
+  require Logger
+
+  alias Lux.LLM.Ollama.Model
+  alias Lux.LLM.Ollama.Cache
+
+  @default_base_url "http://localhost:11434"
+  @default_timeout 300_000
+  @default_max_tokens 2048
+  @default_temperature 0.7
+
+  defstruct [
+    :base_url,
+    :model,
+    :temperature,
+    :max_tokens,
+    :timeout,
+    :stream,
+    :format,
+    :options
+  ]
+
+  @type t :: %__MODULE__{
+          base_url: String.t(),
+          model: String.t(),
+          temperature: float(),
+          max_tokens: integer(),
+          timeout: integer(),
+          stream: boolean(),
+          format: map() | nil,
+          options: map()
+        }
+
+  @doc """
+  Creates a new Ollama client configuration.
+
+  ## Options
+
+    * `:base_url` - Ollama API base URL (default: http://localhost:11434)
+    * `:model` - Model name to use (required)
+    * `:temperature` - Sampling temperature (default: 0.7)
+    * `:max_tokens` - Maximum tokens to generate (default: 2048)
+    * `:timeout` - Request timeout in milliseconds (default: 300000)
+    * `:stream` - Whether to stream responses (default: false)
+    * `:format` - JSON schema for structured output (default: nil)
+    * `:options` - Additional Ollama options (default: %{})
+
+  ## Examples
+
+      iex> Lux.LLM.Ollama.new(model: "llama3.2")
+      %Lux.LLM.Ollama{base_url: "http://localhost:11434", model: "llama3.2", ...}
+  """
+  @spec new(keyword()) :: t()
+  def new(opts \\ []) do
+    base_url = opts[:base_url] || System.get_env("OLLAMA_BASE_URL", @default_base_url)
+
+    %__MODULE__{
+      base_url: base_url,
+      model: opts[:model] || raise(ArgumentError, "model option is required"),
+      temperature: opts[:temperature] || @default_temperature,
+      max_tokens: opts[:max_tokens] || @default_max_tokens,
+      timeout: opts[:timeout] || @default_timeout,
+      stream: opts[:stream] || false,
+      format: opts[:format],
+      options: opts[:options] || %{}
+    }
+  end
+
+  @doc """
+  Sends a chat completion request to Ollama.
+
+  ## Examples
+
+      iex> client = Lux.LLM.Ollama.new(model: "llama3.2")
+      iex> Lux.LLM.Ollama.chat(client, [%{role: "user", content: "Hello!"}])
+      {:ok, %{message: %{role: "assistant", content: "Hi there!"}}}
+  """
+  @spec chat(t(), list(map()), keyword()) :: {:ok, map()} | {:error, term()}
+  def chat(client, messages, _opts \\ []) do
+    body = build_chat_request(client, messages)
+
+    case post(client, "/api/chat", body) do
+      {:ok, response} ->
+        {:ok, parse_chat_response(response)}
+
+      {:error, reason} ->
+        {:error, reason}
+    end
+  end
+
+  @doc """
+  Streams a chat completion request to Ollama.
+
+  Returns a stream of response chunks.
+  """
+  @spec stream_chat(t(), list(map()), keyword()) :: Enumerable.t()
+  def stream_chat(client, messages, _opts \\ []) do
+    body =
+      client
+      |> build_chat_request(messages)
+      |> Map.put("stream", true)
+
+    Stream.resource(
+      fn -> body end,
+      fn _ ->
+        case post(client, "/api/chat", body) do
+          {:ok, response} ->
+            {[response], nil}
+
+          {:error, _reason} ->
+            {:halt, nil}
+        end
+      end,
+      fn _ -> :ok end
+    )
+  end
+
+  @doc """
+  Generates a completion using the specified model.
+
+  ## Examples
+
+      iex> client = Lux.LLM.Ollama.new(model: "llama3.2")
+      iex> Lux.LLM.Ollama.generate(client, "Once upon a time")
+      {:ok, %{response: "..."}}
+  """
+  @spec generate(t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
+  def generate(client, prompt, _opts \\ []) do
+    body = %{
+      "model" => client.model,
+      "prompt" => prompt,
+      "options" => build_options(client),
+      "stream" => false
+    }
+
+    case post(client, "/api/generate", body) do
+      {:ok, response} ->
+        {:ok, parse_generate_response(response)}
+
+      {:error, reason} ->
+        {:error, reason}
+    end
+  end
+
+  @doc """
+  Checks if the Ollama server is available.
+  """
+  @spec available?(t()) :: boolean()
+  def available?(client) do
+    case get(client, "/api/tags") do
+      {:ok, _} -> true
+      _ -> false
+    end
+  end
+
+  @doc """
+  Lists available models on the Ollama server.
+  """
+  @spec list_models(t()) :: {:ok, list(map())} | {:error, term()}
+  def list_models(client) do
+    case get(client, "/api/tags") do
+      {:ok, %{"models" => models}} -> {:ok, models}
+      {:ok, response} -> {:ok, response}
+      {:error, reason} -> {:error, reason}
+    end
+  end
+
+  @doc """
+  Pulls a model from the Ollama library.
+  """
+ 