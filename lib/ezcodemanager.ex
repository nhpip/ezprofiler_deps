defmodule EZProfiler.Manager do

  @moduledoc """
  A module that provides the ability to perform code profiling programmatically rather than via a CLI.

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
  Start it

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

  def stop_ezprofiler(), do:
    Kernel.apply(EZProfiler.ProfilerOnTarget, :stop_profiling, [node()])

  def enable_profiling(label \\ :any_label), do:
    Kernel.apply(EZProfiler.ProfilerOnTarget, :allow_code_profiling, [node(), label, self()])

  def disable_profiling(), do:
    Kernel.apply(EZProfiler.ProfilerOnTarget, :reset_profiling, [node()])

  def wait_for_results(timeout \\ 60000) do
    receive do
      :results_available -> :ok
    after
      timeout -> {:error, :timeout}
    end
  end

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
