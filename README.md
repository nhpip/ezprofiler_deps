# ezprofiler_deps

Provides application-side dependencies for `ezprofiler`:

https://github.com/nhpip/ezprofiler

Specifically it contains a stub module for code profiling:

https://hexdocs.pm/ezprofiler/EZProfiler.CodeProfiler.html

It also provides a module to allow profiling of code from within your application code-base:

https://hexdocs.pm/ezprofiler_deps/EZProfiler.Manager.html


## Installation

Add `ezprofiler_deps` and `ezprofiler` to your list of dependencies in `mix.exs`:

```elixir
  defp deps do
    [
      {:ezprofiler, git: "https://github.com/nhpip/ezprofiler.git", app: false},
      {:ezprofiler_deps, git: "https://github.com/nhpip/ezprofiler_deps.git"}
    ]
```

Please refer to the `hex` docs for more information:

https://hexdocs.pm/ezprofiler/api-reference.html

https://hexdocs.pm/ezprofiler_deps/api-reference.html
