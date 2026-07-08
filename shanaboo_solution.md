 ```diff
--- a/lux/lib/lux/llm/ollama.ex
+++ b/lux/lib/lux/llm/ollama.ex
@@ -0,0 +1,312 @@
+defmodule Lux.LLM.Ollama do
+  @moduledoc """
+  Ollama LLM client for local model support.
+
+  Provides integration with Ollama API for running local LLMs.
+  See https://github.com/ollama/ollama/blob/main/docs/api.md
+  """
+
+  alias Lux.LLM.Response
+
+  @behaviour Lux.LLM
+
+  @default_endpoint "http://localhost:11434"
+  @default_timeout 300_000
+  @default_max_tokens 2048
+
+  @type t :: %__MODULE__{
+          endpoint: String.t(),
+          model: String.t(),
+          temperature: float(),
+          max_tokens: integer(),
+          timeout: integer(),
+          system: String.t() | nil,
+          stream: boolean(),
+          format: map() | nil,
+          options: map()
+        }
+
+  defstruct [
+    :endpoint,
+    :model,
+    :temperature,
+    :max_tokens,
+    :timeout,
+    :system,
+    :stream,
+    :format,
+    :options
+  ]
+
+  @impl true
+  def new(opts \\ []) do
+    %__MODULE__{
+      endpoint: opts[:endpoint] || default_endpoint(),
+      model: opts[:model] || default_model(),
+      temperature: opts[:temperature] || 0.7,
+      max_tokens: opts[:max_tokens] || @default_max_tokens,
+      timeout: opts[:timeout] || @default_timeout,
+      system: opts[:system],
+      stream: opts[:stream] || false,
+      format: opts[:format],
+      options: opts[:options] || %{}
+    }
+  end
+
+  @impl true
+  def call(messages, config) do
+    config = config || new()
+
+    body = build_request_body(messages, config)
+
+    headers = [
+      {"Content-Type", "application/json"}
+    ]
+
+    url = "#{config.endpoint}/api/chat"
+
+    start_time = System.monotonic_time(:millisecond)
+
+    case HTTPoison.post(url, Jason.encode!(body), headers,
+           recv_timeout: config.timeout,
+           timeout: config.timeout
+         ) do
+      {:ok, %{status_code: 200, body: response_body}} ->
+        response = Jason.decode!(response_body)
+        end_time = System.monotonic_time(:millisecond)
+        latency_ms = end_time - start_time
+
+        {:ok, parse_response(response, latency_ms)}
+
+      {:ok, %{status_code: status_code, body: response_body}} ->
+        error =
+          try do
+            Jason.decode!(response_body)
+          rescue
+            _ -> %{"error" => response_body}
+          end
+
+        {:error, %{status: status_code, error: error}}
+
+      {:error, %HTTPoison.Error{reason: reason}} ->
+        {:error, %{reason: reason}}
+    end
+  end
+
+  @doc """
+  Streams a chat completion from Ollama.
+  """
+  def stream(messages, config, callback) do
+    config = config || new()
+
+    body =
+      build_request_body(messages, config)
+      |> Map.put(:stream, true)
+
+    headers = [
+      {"Content-Type", "application/json"}
+    ]
+
+    url = "#{config.endpoint}/api/chat"
+
+    start_time = System.monotonic_time(:millisecond)
+
+    HTTPoison.post!(
+      url,
+      Jason.encode!(body),
+      headers,
+      stream_to: self(),
+      async: :once,
+      recv_timeout: config.timeout,
+      timeout: config.timeout
+    )
+
+    stream_response(start_time, callback, "")
+  end
+
+  defp stream_response(start_time, callback, accumulated) do
+    receive do
+      %HTTPoison.AsyncChunk{chunk: chunk} ->
+        {new_accumulated, done} = process_stream_chunk(chunk, accumulated, callback)
+
+        if done do
+          end_time = System.monotonic_time(:millisecond)
+          latency_ms = end_time - start_time
+          {:ok, latency_ms}
+        else
+          stream_response(start_time, callback, new_accumulated)
+        end
+
+      %HTTPoison.AsyncEnd{} ->
+        end_time = System.monotonic_time(:millisecond)
+        latency_ms = end_time - start_time
+        {:ok, latency_ms}
+
+      %HTTPoison.AsyncStatus{code: status} when status != 200 ->
+        {:error, %{status: status}}
+
+      %HTTPoison.AsyncHeaders{} ->
+        stream_response(start_time, callback, accumulated)
+    after
+      30_000 ->
+        {:error, :timeout}
+    end
+  end
+
+  defp process_stream_chunk(chunk, accumulated, callback) do
+    data = accumulated <> chunk
+
+    case String.split(data, "\n", parts: 2) do
+      [line, rest] ->
+        case Jason.decode(line) do
+          {:ok, %{"message" => %{"content" => content}, "done" => false} = _response} ->
+            callback.({:chunk, content})
+            {rest, false}
+
+          {:ok, %{"done" => true} = _response} ->
+            callback.(:done)
+            {rest, true}
+
+          _ ->
+            {rest, false}
+        end
+
+      _ ->
+        {data, false}
+    end
+  end
+
+  @doc """
+  Generates embeddings using Ollama.
+  """
+  def embeddings(text, opts \\ []) do
+    config = new(opts)
+
+    body = %{
+      model: opts[:embedding_model] || config.model,
+      prompt: text
+    }
+
+    headers = [
+      {"Content-Type", "application/json"}
+    ]
+
+    url = "#{config.endpoint}/api/embeddings"
+
+    case HTTPoison.post(url, Jason.encode!(body), headers,
+           recv_timeout: config.timeout,
+           timeout: config.timeout
+         ) do
+      {:ok, %{status_code: 200, body: response_body}} ->
+        response = Jason.decode!(response_body)
+        {:ok, response["embedding"]}
+
+      {:ok, %{status_code: status_code, body: response_body