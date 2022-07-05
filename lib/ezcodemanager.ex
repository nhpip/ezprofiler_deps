defmodule EZProfiler.Manager do

  defstruct [
    node: nil,
    cookie: nil,
    mf: "_:_",
    directory: "/tmp/",
    maxtime: 60,
    profiler: "eprof",
    sort: "mfa",
    cpfo: "false",
    ezprofiler_path: nil
  ]

  def start_ezprofiler(), do:
    start_ezprofiler(%__MODULE__{})

  def start_ezprofiler(cfg = %__MODULE__{}) do
    Code.ensure_loaded(__MODULE__)

    Map.from_struct(cfg)
    |> Map.replace!(:node, (if is_nil(cfg.node), do: node() |> Atom.to_string(), else: cfg.node))
    |> Map.replace!(:ezprofiler_path, (if is_nil(cfg.ezprofiler_path), do: System.find_executable("ezprofiler"), else: cfg.ezprofiler_path))
    |> Map.to_list()
    |> Enum.filter(&(not is_nil(elem(&1, 1))))
    |> Enum.reduce({nil, []}, fn({:ezprofiler_path, path}, {_, acc}) -> {path, acc};
                                (opt, {path, opts}) -> {path, [make_opt(opt) | opts]} end)
    |> flatten()
    |> do_start_profiler()
  end

  def stop_ezprofiler(), do:
    EZProfiler.ProfilerOnTarget.stop_profiling(node())

  def enable_profiling(label \\ :any_label), do:
    EZProfiler.ProfilerOnTarget.allow_code_profiling(node(), label)

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
    spawn(fn -> System.cmd(System.find_executable(profiler_path), opts) end)
  end

  defp flatten({path, cfg}), do:
    {path, List.flatten(cfg)}

  defp make_opt({:cpfo, v}) when v in [true, "true"], do:
    ["--cpfo"]

  defp make_opt({:cpfo, _v}), do:
    []

  defp make_opt({:maxtime, v}), do:
    ["--maxtime", Integer.to_string(v)]

  defp make_opt({k, v}), do:
    ["--#{k}", (if is_atom(v), do: Atom.to_string(v), else: v)]

  def results_available?() do

  end

end
