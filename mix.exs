defmodule FileBeam.Mixfile do
  use Mix.Project

  def project do
    [
      app: :file_beam,
      version: "0.1.0",
      elixir: "~> 1.6.4",
      elixirc_options: [
        # warnings_as_errors: true
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger, :wobserver], mod: {FileBeam.Application, []}]
  end

  defp deps do
    [
      {:uuid, "~> 1.1"},
      {:ace, "~> 0.16.8"},
      {:phoenix_html, "~> 2.11"},
      {:raxx_static, "~> 0.6.1"},
      # {:exsync, "~> 0.2.3", only: :dev},
      {:dialyxir, "~> 0.5.1", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false},
      {:wobserver, "~> 0.1.8"}
    ]
  end
end
