defmodule EZProfiler.Manager do

  @moduledoc """
  A module that provides the ability to perform code profiling programmatically rather than via a CLI.

  Use of this module still requires the `ezprofiler` escript, but it shall be automatically initialized in the background.

  ## Example

        with {:ok, :started} <- EZProfiler.Manager.start_ezprofiler(%EZProfiler.Manager{ezprofiler_path: :deps}),
           :ok <- EZProfiler.Manager.enable_profiling(),
           :ok <- EZProfiler.Manager.wait_for_results(),
           {:ok, filename, results} <- EZProfiler.Manager.get_profiling_results(true)
        do
          EZProfiler.Manager.stop_ezprofiler()
          {:ok, filename, results}
        else
          rsp ->
            EZProfiler.Manager.stop_ezprofiler()
            rsp
        end

  """

  defstruct [
    node: nil,
    cookie: nil,
    mf: "_:_",
    directory: "/tmp/",
    profiler: "eprof",
    sort: "mfa",
    cpfo: "false",
    ezprofiler_path: :system
  ]

  @doc """
  Starts and configures the `ezprofiler` escript. Takes the `%EZProfiler.Manager{}` struct as configuration.

  Most fields map directly onto the equivalent arguments for starting `ezprofiler`.

  The exception to this is `ezprofiler_path` that takes the following options:

        :system - if `ezprofiler` is defined via the `PATH` env variable.
        :deps - if `ezprofiler` is included as an application in `mix.ezs`
        path - a string specifying the full path for `ezprofiler`

  ## Example

        %EZProfiler.Manager{
          cookie: nil,
          cpfo: "false",
          directory: "/tmp/",
          ezprofiler_path: :system,
          mf: "_:_",
          node: nil,
          profiler: "eprof",
          sort: "mfa"
        }

  """
  def start_ezprofiler(cfg = %EZProfiler.Manager{} \\ %EZProfiler.Manager{}) do
    Code.ensure_loaded(__MODULE__)

    Map.from_struct(cfg)
    |> Map.replace!(:node, (if is_nil(cfg.node), do: node() |> Atom.to_string(), else: cfg.node))
    |> Map.replace!(:ezprofiler_path, find_ezprofiler(cfg.ezprofiler_path))
    |> Map.to_list()
    |> Enum.filter(&(not is_nil(elem(&1, 1))))
    |> Enum.reduce({nil, []}, fn({:ezprofiler_path, path}, {_, acc}) -> {path, acc};
                                (opt, {path, opts}) -> {path, [make_opt(opt) | opts]} end)
    |> flatten()
    |> do_start_profiler()
  end

  @doc """
  Stops the `ezprofiler` escript. The equivalent of hitting `q` in the CLI.

  """
  def stop_ezprofiler(), do:
    Kernel.apply(EZProfiler.ProfilerOnTarget, :stop_profiling, [node()])

  @doc """
  Enables code profiling. The equivalent of hitting `c` or `c label` in the CLI.

  """
  def enable_profiling(label \\ :any_label), do:
    Kernel.apply(EZProfiler.ProfilerOnTarget, :allow_code_profiling, [node(), label, self()])

  @doc """
  Disables code profiling. The equivalent of hitting `r` in the CLI.

  """
  def disable_profiling(), do:
    Kernel.apply(EZProfiler.ProfilerOnTarget, :reset_profiling, [node()])

  @doc """
  Waits `timeout` seconds (default 60) for code profiling to complete.

  """
  def wait_for_results(timeout \\ 60) do
    timeout = timeout * 1000
    receive do
      :results_available -> :ok
    after
      timeout -> {:error, :timeout}
    end
  end

  @doc """
  Returns the resulting code profiling results. If the option `display` is set to true it will also output the `stdout`.

  On success it will return the tuple `{:ok, filename, result_string}`

  """
  def get_profiling_results(display \\ false) do
    send({:main_event_handler, :ezprofiler@localhost}, {:get_results_file, self()})
    receive do
      {:profiling_results, filename, results} ->
        if display, do: IO.puts(results)
        {:ok, filename, results}
      {:no_profiling_results, results} ->
        {:error, results}
    after
      2000 -> {:error, :timeout}
    end
  end

  defp do_start_profiler({profiler_path, opts}) do
    pid = self()
    spawn(fn ->
            try do
              filename = "/tmp/#{random_filename()}"
              spawn(fn -> wait_for_start(pid, filename) end)
              System.cmd(System.find_executable(profiler_path), ["--inline", filename | opts])
            rescue
              e ->
                send(pid, {__MODULE__, {:error, e}})
            end
    end)
    receive do
      {__MODULE__, rsp} -> rsp
    after
      5000 -> {:error, :timeout}
    end
  end

  defp find_ezprofiler(:system) do
    System.find_executable("ezprofiler")
  end

  defp find_ezprofiler(:deps) do
    path = Mix.Dep.cached()
           |> Enum.find(&(&1.app == :ezprofiler))
           |> Map.get(:opts)
           |> Keyword.get(:dest)
    "#{path}/ezprofiler"
  end

  defp find_ezprofiler(path) do
    path
  end

  defp flatten({path, cfg}), do:
    {path, List.flatten(cfg)}

  defp make_opt({:cpfo, v}) when v in [true, "true"], do:
    ["--cpfo"]

  defp make_opt({:cpfo, _v}), do:
    []

  defp make_opt({k, v}), do:
    ["--#{k}", (if is_atom(v), do: Atom.to_string(v), else: v)]

  defp wait_for_start(pid, filename) do
    if do_wait_for_start(filename, 10),
      do: send(pid, {__MODULE__, {:ok, :started}}),
      else: send(pid, {__MODULE__, {:error, :not_started}})
  end

  defp do_wait_for_start(_filename, 0), do:
    false

  defp do_wait_for_start(filename, count) do
    Process.sleep(500)
    File.exists?(filename) || do_wait_for_start(filename, count - 1)
  end

  defp random_filename() do
    for _ <- 1..10, into: "", do: <<Enum.at('abcdefghijklmnopqrstuvwxyz', :crypto.rand_uniform(0, 26))>>
  end

end
