defmodule LiveQuery.MixProject do
  use Mix.Project

  def project do
    [
      name: "LiveQuery",
      description: "Separate how you load data from where you load data.",
      app: :live_query,
      package: [
        licenses: ["MIT"],
        links: %{
          "Source Code" => "https://github.com/AHBruns/live_query",
          "GitHub" => "https://github.com/AHBruns/live_query"
        }
      ],
      docs: [
        main: "LiveQuery"
      ],
      version: "0.3.1",
      source_url: "https://github.com/AHBruns/live_query",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [{:ex_doc, "~> 0.27", only: :dev, runtime: false}]
  end
end
