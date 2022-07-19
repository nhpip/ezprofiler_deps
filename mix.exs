defmodule EZProfilerDeps.MixProject do
  use Mix.Project

  def project do
    [
      app: :ezprofiler_deps,
      version: "1.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      package: package(),
      description: description(),
      name: "ezprofiler_deps",
      deps: deps()
    ]
  end

  defp description() do
    "Application-side dependancy that works in conjunction with `ezprofiler`. Provides the ability to do code profiling
     within your application as well as `ezprofiler` management. THe `ezprofiler` escript can be obtained from:
     https://github.com/nhpip/ezprofiler.git"
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:crypto]
    ]
  end

  defp package() do
    [
      files: ~w(lib mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/nhpip/ezprofiler_deps"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
     {:ex_doc, "~> 0.28.4", only: :dev, runtime: false}
    ]
  end
end
