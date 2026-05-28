defmodule Lux.LLM.Perplexity do
  @moduledoc """
  Perplexity AI API client for Lux framework.
  
  Provides integration with Perplexity AI's advanced language models
  with support for streaming responses, model selection, and cost tracking.
  """

  require Logger

  @base_url "https://api.perplexity.ai"
  @api_key Application.get_env(:lux, :perplexity_api_key)

  @doc """
  Sends a completion request to Perplexity AI.

  ## Options
    * `:model` - The model to use for completion
    * `:stream` - Whether to stream the response
    * `:temperature` - Sampling temperature
    * `:max_tokens` - Maximum number of tokens to generate
  """
  @spec complete(String.t(), keyword()) :: {:ok, map()} | {:error, any()}
  def complete(prompt, opts \\ []) do
    model = Keyword.get(opts, :model, "llama-3.1-sonar-large-128k-online")
    stream = Keyword.get(opts, :stream, false)
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 1024)

    body = %{
      model: model,
      messages: [%{role: "user", content: prompt}],
      temperature: temperature,
      max_tokens: max_tokens,
      stream: stream
    }

    headers = [
      {"Authorization", "Bearer #{@api_key}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    url = "#{@base_url}/chat/completions"

    case HTTPoison.post(url, Jason.encode!(body), headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        if stream do
          handle_streaming_response(body)
        else
          handle_regular_response(body)
        end

      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        {:error, "Perplexity API error: #{status} - #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Network error: #{reason}"}
    end
  end

  @doc """
  Streams a completion request to Perplexity AI.
  """
  @spec stream(String.t(), keyword()) :: {:ok, Enumerable.t()} | {:error, any()}
  def stream(prompt, opts \\ []) do
    model = Keyword.get(opts, :model, "llama-3.1-sonar-large-128k-online")
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 1024)

    body = %{
      model: model,
      messages: [%{role: "user", content: prompt}],
      temperature: temperature,
      max_tokens: max_tokens,
      stream: true
    }

    headers = [
      {"Authorization", "Bearer #{@api_key}"},
      {"Content-Type", "application/json"}
    ]

    url = "#{@base_url}/chat/completions"

    {:ok, stream} = HTTPoison.post(url, Jason.encode!(body), headers, stream_to: self(), async: :once)
    {:ok, stream}
  end

  @doc """
  Lists available models from Perplexity AI.
  """
  @spec list_models() :: {:ok, [map()]} | {:error, any()}
  def list_models() do
    headers = [
      {"Authorization", "Bearer #{@api_key}"},
      {"Content-Type", "application/json"}
    ]

    url = "#{@base_url}/models"

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        {:error, "Perplexity API error: #{status} - #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Network error: #{reason}"}
    end
  end

  defp handle_regular_response(body) do
    case Jason.decode(body) do
      {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
        {:ok, %{content: content}}

      {:error, reason} ->
        {:error, "JSON decode error: #{reason}"}
    end
  end

  defp handle_streaming_response(body) do
    # For streaming, we return the raw stream to be handled by the caller
    {:ok, body}
  end

  @doc """
  Calculates estimated cost for a request based on token usage.
  """
  @spec calculate_cost(integer(), integer()) :: float()
  def calculate_cost(prompt_tokens, completion_tokens) do
    # Example pricing - should be updated with actual Perplexity pricing
    prompt_cost = prompt_tokens * 0.00003
    completion_cost = completion_tokens * 0.00006
    prompt_cost + completion_cost
  end
end