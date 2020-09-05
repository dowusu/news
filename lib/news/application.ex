defmodule News.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Starts a worker by calling: News.Worker.start_link(arg)
      # {News.Worker, arg}
      News.HackerNewsClient.child_spec()
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: News.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
