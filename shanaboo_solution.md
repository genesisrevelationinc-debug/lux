 ```diff
--- /dev/null
+++ b/lux/lib/lux/llm/ollama.ex
@@ -0,0 +1,316 @@
+defmodule Lux.LLM.Ollama do
+  @moduledoc """
+  Ollama client for local LLM support.
+
+  Provides integration with Ollama API for running local models,
+  with support for model management, caching, and resource controls.
+  """
+
+  require Logger
+
+  @default_base_url "http://localhost:11434"
+  @default_timeout 300_000
+  @default_connect_timeout 30_000
+
+  @type model_name :: String.t()
+  @type prompt :: String.t()
+  @type options :: keyword()
+  @type response :: {:ok, map()} | {:error, term()}
+
+  defmodule Config do
+    @moduledoc """
+    Configuration for Ollama client.
+    """
+
+    defstruct [
+      :base_url,
+      :timeout,
+      :connect_timeout,
+      :default_model,
+      :cache_enabled,
+      :max_memory_mb,
+      :max_concurrent_requests
+    ]
+
+    @type t :: %__MODULE__{
+            base_url: String.t(),
+            timeout: non_neg_integer(),
+            connect_timeout: non_neg_integer(),
+            default_model: String.t() | nil,
+            cache_enabled: boolean(),
+            max_memory_mb: non_neg_integer() | nil,
+            max_concurrent_requests: pos_integer() | nil
+          }
+  end
+
+  @doc """
+  Returns the default configuration.
+  """
+  @spec default_config() :: Config.t()
+  def default_config do
+    %Config{
+      base_url: System.get_env("OLLAMA_BASE_URL", @default_base_url),
+      timeout: parse_env_integer("OLLAMA_TIMEOUT", @default_timeout),
+      connect_timeout: parse_env_integer("OLLAMA_CONNECT_TIMEOUT", @default_connect_timeout),
+      default_model: System.get_env("OLLAMA_DEFAULT_MODEL"),
+      cache_enabled: parse_env_boolean("OLLAMA_CACHE_ENABLED", true),
+      max_memory_mb: parse_env_integer("OLLAMA_MAX_MEMORY_MB", nil),
+      max_concurrent_requests: parse_env_integer("OLLAMA_MAX_CONCURRENT_REQUESTS", 4)
+    }
+  end
+
+  defp parse_env_integer(key, default) do
+    case System.get_env(key) do
+      nil -> default
+      val -> String.to_integer(val)
+    end
+  end
+
+  defp parse_env_boolean(key, default) do
+    case System.get_env(key) do
+      nil -> default
+      "true" -> true
+      "1" -> true
+      _ -> false
+    end
+  end
+
+  @doc """
+  Generates a completion using the specified model.
+  """
+  @spec completion(model_name(), prompt(), options()) :: response()
+  def completion(model, prompt, options \\ []) do
+    config = Keyword.get(options, :config, default_config())
+    cache_key = generate_cache_key(model, prompt, options)
+
+    with :ok <- check_resource_limits(config),
+         {:ok, cached} <- maybe_get_cached(cache_key, config) do
+      case cached do
+        nil ->
+          do_completion(model, prompt, options, config, cache_key)
+
+        result ->
+          {:ok, result}
+      end
+    end
+  end
+
+  defp do_completion(model, prompt, options, config, cache_key) do
+    body = %{
+      model: model,
+      prompt: prompt,
+      stream: false,
+      options: build_options(options)
+    }
+
+    start_time = System.monotonic_time()
+
+    result = post("/api/generate", body, config)
+
+    end_time = System.monotonic_time()
+    duration_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)
+
+    case result do
+      {:ok, response} ->
+        maybe_cache_result(cache_key, response, config)
+        log_performance(model, duration_ms, byte_size(prompt))
+        {:ok, response}
+
+      error ->
+        error
+    end
+  end
+
+  @doc """
+  Generates a chat completion using the specified model.
+  """
+  @spec chat(model_name(), list(map()), options()) :: response()
+  def chat(model, messages, options \\ []) do
+    config = Keyword.get(options, :config, default_config())
+
+    with :ok <- check_resource_limits(config) do
+      body = %{
+        model: model,
+        messages: messages,
+        stream: false,
+        options: build_options(options)
+      }
+
+      post("/api/chat", body, config)
+    end
+  end
+
+  @doc """
+  Lists available models.
+  """
+  @spec list_models() :: response()
+  def list_models(options \\ []) do
+    config = Keyword.get(options, :config, default_config())
+    get("/api/tags", config)
+  end
+
+  @doc """
+  Pulls a model from the Ollama library.
+  """
+  @spec pull_model(model_name()) :: response()
+  def pull_model(model, options \\ []) do
+    config = Keyword.get(options, :config, default_config())
+    post("/api/pull", %{name: model, stream: false}, config)
+  end
+
+  @doc """
+  Deletes a model.
+  """
+  @spec delete_model(model_name()) :: response()
+  def delete_model(model, options \\ []) do
+    config = Keyword.get(options, :config, default_config())
+    delete("/api/delete", %{name: model}, config)
+  end
+
+  @doc """
+  Shows model information.
+  """
+  @spec show_model(model_name()) :: response()
+  def show_model(model, options \\ []) do
+    config = Keyword.get(options, :config, default_config())
+    post("/api/show", %{name: model}, config)
+  end
+
+  @doc """
+  Checks if Ollama is running and accessible.
+  """
+  @spec health_check() :: :ok | {:error, term()}
+  def health_check(options \\ []) do
+    config = Keyword.get(options, :config, default_config())
+
+    case get("/api/tags", config) do
+      {:ok, _} -> :ok
+      error -> error
+    end
+  end
+
+  # Private functions
+
+  defp build_options(options) do
+    allowed = [:temperature, :num_ctx