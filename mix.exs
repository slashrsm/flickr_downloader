defmodule FlickrDownloader.MixProject do
  use Mix.Project

  def project do
    [
      app: :flickr_downloader,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :flickrex, :httpoison]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:flickrex, "~> 0.7"},
      {:httpoison, "~> 1.5"},
    ]
  end
end
