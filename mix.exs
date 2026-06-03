defmodule Livecode.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/go9/livecode"

  def project do
    [
      app: :livecode,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "LiveView-native syntax highlighting, autocomplete, snippets, and diagnostics for textareas.",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:phoenix_live_view, ">= 1.0.0"},
      {:jason, ">= 1.4.0"},
      {:ex_doc, ">= 0.34.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "LiveCode",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
end
