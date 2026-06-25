 Looking at this issue, I need to implement an OpenRouter integration for the Lux framework. This is an Elixir project based on the file structure. Let me analyze what's needed:

1. OpenRouter API client
2. Multiple model support
3. Unified interface matching other providers
4. Error handling and retries
5. Cost tracking

Since this is an Elixir project with a `lux` directory, I'll need to create the OpenRouter integration files. Let me infer the structure from typical Elixir projects and the issue requirements.

Based on the repo structure, the main code is likely in `lux/lib/` and tests in `lux/test/`. I'll create:

1. `lux/lib/lux/llm/providers/open_router.ex` - Main OpenRouter client
2. `lux/lib/lux/llm/providers/open_router/client.ex` - HTTP client
3. `lux/lib/lux/llm/providers/open_router/models.ex` - Model definitions
4. `lux/lib/lux/llm/providers/open_router/cost_tracker.ex` - Cost tracking
5. `lux/test/lux/llm/providers/open_router_test.exs` - Tests

Let me create these files:

```diff
--- /dev/null
+++ b/lux/lib/lux/llm/providers/open_router.ex
@@ -0,0 +1,218 @@
+defmodule Lux.LLM.Providers.OpenRouter do
+  @moduledoc """
+  OpenRouter integration for Lux, providing access to a wide range of LLM models
+  through a single unified API.
+
+  ## Configuration
+
+  Configure OpenRouter in your application config:
+
+      config :lux, Lux.LLM.Providers.OpenRouter,
+        api_key: System.get_env("OPENROUTER_API_KEY"),
+        default_model: "anthropic/claude-3.5-sonnet",
+        site_url: "https://your-site.com",
+        site_name: "Your App"
+
+  ## Usage
+
+      alias Lux.LLM.Providers.OpenRouter
+
+      # Simple chat completion
+      {:ok, response} = OpenRouter.chat([
+        %{role: "user", content: "Hello!"}
+      ])
+
+      # With specific model
+      {:ok, response} = OpenRouter.chat([
+        %{role: "user", content: "Hello!"}
+      ], model: "openai/gpt-4o")
+
+      # With streaming
+      {:ok, stream} = OpenRouter.chat([
+        %{role: "user", content: "Tell me a story"}
+      ], stream: true, stream_to: self())
+  """
+
+  alias Lux.LLM.Providers.OpenRouter.{Client, CostTracker, Models}
+
+  @default_timeout 60_000
+  @default_max_retries 3
+
+  @type message :: %{
+          role: String.t(),
+          content: String.t(),
+          optional(:name) => String.t()
+        }
+
+  @type chat_options :: [
+          model: String.t(),
+          temperature: float(),
+          max_tokens: integer(),
+          top_p: float(),
+          stream: boolean(),
+          stream_to: pid() | atom(),
+          tools: list(),
+          tool_choice: map() | String.t(),
+          timeout: integer(),
+          max_retries: integer()
+        ]
+
+  @type chat_response :: %{
+          id: String.t(),
+          model: String.t(),
+          content: String.t(),
+          usage: map(),
+          finish_reason: String.t(),
+          created_at: DateTime.t()
+        }
+
+  @doc """
+  Sends a chat completion request to OpenRouter.
+
+  ## Options
+
+  - `:model` - Model identifier (default from config or "anthropic/claude-3.5-sonnet")
+  - `:temperature` - Sampling temperature (0.0 to 2.0, default: 0.7)
+  - `:max_tokens` - Maximum tokens to generate
+  - `:top_p` - Nucleus sampling parameter
+  - `:stream` - Enable streaming (default: false)
+  - `:stream_to` - PID or process/multicast name to send stream events to
+  - `:tools` - List of tool definitions for function calling
+  - `:tool_choice` - Tool choice strategy
+  - `:timeout` - Request timeout in milliseconds
+  - `:max_retries` - Maximum retry attempts
+  """
+  @spec chat(list(message()), chat_options()) ::
+          {:ok, chat_response()} | {:ok, Enumerable.t()} | {:error, term()}
+  def chat(messages, opts \\ []) do
+    model = Keyword.get(opts, :model, default_model())
+    stream = Keyword.get(opts, :stream, false)
+
+    body = build_request_body(messages, model, opts)
+
+    if stream do
+      stream_chat(body, opts)
+    else
+      do_chat(body, opts)
+    end
+  end
+
+  @doc """
+  Returns a list of available models from OpenRouter.
+  """
+  @spec list_models() :: {:ok, list(map())} | {:error, term()}
+  def list_models do
+    case Client.request(:get, "/models") do
+      {:ok, %{"data" => models}} -> {:ok, Enum.map(models, &Models.normalize/1)}
+      {:error, reason} -> {:error, reason}
+    end
+  end
+
+  @doc """
+  Returns model information for a specific model.
+  """
+  @spec get_model(String.t()) :: {:ok, map()} | {:error, term()}
+  def get_model(model_id) do
+    case Client.request(:get, "/models/#{URI.encode_www_form(model_id)}") do
+      {:ok, model} -> {:ok, Models.normalize(model)}
+      {:error, reason} -> {:error, reason}
+    end
+  end
+
+  @doc """
+  Returns the current credit balance and usage statistics.
+  """
+  @spec get_credits() :: {:ok, map()} | {:error, term()}
+  def get_credits do
+    Client.request(:get, "/credits")
+  end
+
+  # Private functions
+
+  defp do_chat(body, opts) do
+    timeout = Keyword.get(opts, :timeout, @default_timeout)
+    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
+
+    case Client.request(:post, "/chat/completions", body, timeout: timeout, max_retries: max_retries) do
+      {:ok, response} ->
+        response = parse_response(response)
+        CostTracker.track(response)
+        {:ok, response}
+
+      {:error, reason} ->
+        {:error, reason}
+   