defmodule Ueberauth.StackOverflow.Mixfile do
  use Mix.Project

  @version "0.0.2"
  @source_url "https://github.com/cgorshing/ueberauth_stackoverflow"

  def project do
    [app: :ueberauth_stackoverflow,
     version: @version,
     name: "Ueberauth StackOverflow",
     package: package(),
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     source_url: @source_url,
     homepage_url: "https://github.com/cgorshing/ueberauth_stackoverflow",
     description: description(),
     deps: deps(),
     docs: docs()]
  end

  #config :oauth2, serializers: %{ "application/json" => JsonHandler }

  def application do
    [
      applications: [:logger, :ueberauth, :oauth2]
    ]
  end

  defp deps do
    [
     {:oauth2, "~> 0.9.1"},
     {:ueberauth, "~> 0.4.0"},

     # dev/test only dependencies
     {:credo, "~> 0.8", only: [:dev, :test]},

     # docs dependencies
     {:earmark, ">= 0.0.0", only: :dev},
     {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp docs do
    [extras: ["README.md"]]
  end

  defp description do
    "An Ueberauth strategy for using StackOverflow to authenticate your users."
  end

  defp package do
    [files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Chad Gorshing"],
      licenses: ["MIT"],
      links: %{"GitHub": "https://github.com/cgorshing/ueberauth_stackoverflow"}]
  end
end
