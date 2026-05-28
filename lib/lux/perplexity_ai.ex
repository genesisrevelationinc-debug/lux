defmodule Lux.Application do
  @moduledoc """
  Perplexity AI integration for Lux
  """
  use GenServer
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec
    children = [
      worker(Lux.PerplexityAI, [])
    ]
    opts = [strategy: :one_for_one, name: Lux.PerplexityAI]
    Supervisor.start_link(children, opts)
  end
end