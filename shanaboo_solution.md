 ```diff
--- a/lux/lib/lux/llm/ollama.ex
+++ b/lux/llm/ollama.ex
@@ -0,0 +1,200 @@
+defmodule Lux.LLM.Ollama do
+  @moduledoc """
+  Ollama client for local LLM support.
+  Provides integration with Ollama API for running local models.
+  """
+
+  require Logger
+
+  @default_base_url "http://localhost:11434"
+  @default_timeout 300_000
+  @default_model "llama3"
+
+  defstruct [
+    :base_url,
+    :model,
+    :timeout,
+    :stream
+  ]
+
+  @type t :: %__MODULE__{
+          base_url: String.t(),
+          model: String.t(),
+          timeout: non_neg_integer(),
+          stream: boolean()
+        }
+
+  @doc """
+  Creates a new Ollama client configuration.
+
+  ## Options
+    * `:base_url` - Ollama API base URL (default: http://localhost:11434)
+    * `:model` - Model name to use (default: llama3)
+    * `:timeout` - Request timeout in milliseconds (default: 300000)
+    * `:stream` - Whether to stream responses (default: false)
+  """
+  @spec new(keyword()) :: t()
+  def new(opts \\ []) do
+    %__MODULE__{
+      base_url: Keyword.get(opts, :base_url, @default_base_url),
+      model: Keyword.get(opts, :model, @default_model),
+      timeout: Keyword.get(opts, :timeout, @default_timeout),
+      stream: Keyword.get(opts, :stream, false)
+    }
+  end
+
+  @doc """
+  Generates a completion using the configured model.
+  """
+  @spec completion(t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
+  def completion(client, prompt, opts \\ []) do
+    body = %{
+      model: client.model,
+      prompt: prompt,
+      stream: client.stream,
+      options: opts[:options] || %{}
+    }
+
+    request(client, "/api/generate", body)
+  end
+
+  @doc """
+  Generates a chat completion using the configured model.
+  """
+  @spec chat(t(), list(map()), keyword()) :: {:ok, map()} | {:error, term()}
+  def chat(client, messages, opts \\ []) do
+    body = %{
+      model: client.model,
+      messages: messages,
+      stream: client.stream,
+      options: opts[:options] || %{}
+    }
+
+    request(client, "/api/chat", body)
+  end
+
+  @doc """
+  Pulls a model from the Ollama library.
+  """
+  @spec pull_model(t(), String.t()) :: {:ok, map()} | {:error, term()}
+  def pull_model(client, model_name) do
+    body = %{
+      name: model_name,
+      stream: false
+    }
+
+    request(client, "/api/pull", body)
+  end
+
+  @doc """
+  Lists locally available models.
+  """
+  @spec list_local_models(t()) :: {:ok, list(map())} | {:error, term()}
+  def list_local_models(client) do
+    case request(client, "/api/tags", nil, :get) do
+      {:ok, %{"models" => models}} -> {:ok, models}
+      {:ok, response} -> {:ok, response}
+      error -> error
+    end
+  end
+
+  @doc """
+  Deletes a local model.
+  """
+  @spec delete_model(t(), String.t()) :: {:ok, map()} | {:error, term()}
+  def delete_model(client, model_name) do
+    body = %{name: model_name}
+    request(client, "/api/delete", body, :delete)
+  end
+
+  @doc """
+  Shows model information.
+  """
+  @spec show_model(t(), String.t()) :: {:ok, map()} | {:error, term()}
+  def show_model(client, model_name) do
+    body = %{name: model_name}
+    request(client, "/api/show", body)
+  end
+
+  @doc """
+  Checks if Ollama server is running.
+  """
+  @spec health_check(t()) :: :ok | {:error, term()}
+  def health_check(client) do
+    case HTTPoison.get("#{client.base_url}/api/tags", [], timeout: 5000, recv_timeout: 5000) do
+      {:ok, %{status_code: 200}} -> :ok
+      {:ok, %{status_code: status}} -> {:error, "Unexpected status: #{status}"}
+      {:error, reason} -> {:error, reason}
+    end
+  end
+
+  # Private functions
+
+  defp request(client, path, body, method \\ :post) do
+    url = client.base_url <> path
+    headers = [{"Content-Type", "application/json"}]
+
+    opts = [
+      timeout: client.timeout,
+      recv_timeout: client.timeout
+    ]
+
+    response =
+      case method do
+        :get -> HTTPoison.get(url, headers, opts)
+        :delete -> HTTPoison.delete(url, headers, opts)
+        _ -> HTTPoison.post(url, Jason.encode!(body), headers, opts)
+      end
+
+    case response do
+      {:ok, %{status_code: status, body: resp_body}} when status in 200..299 ->
+        case Jason.decode(resp_body) do
+          {:ok, decoded} -> {:ok, decoded}
+          {:error, _} -> {:ok, %{"response" => resp_body}}
+        end
+
+      {:ok, %{status_code: status, body: resp_body}} ->
+        {:error, %{status: status, body: resp_body}}
+
+      {:error, reason} ->
+        {:error, reason}
+    end
+  end
+end
--- a/lux/lib/lux/llm/ollama/model_manager.ex
+++ b/lux/lib/lux/llm/ollama/model_manager.ex
@@ -0,0 +1,200 @@
+defmodule Lux.LLM.Ollama.ModelManager do
+  @moduledoc """
+  Manages Ollama models including download, caching, and resource controls.
+  """
+
+  use GenServer
+  require Logger
+
+  alias Lux.LLM.O