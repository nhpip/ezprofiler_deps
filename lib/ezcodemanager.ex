defmodule EZProfiler.Manager do

  @moduledoc """
  This module requires the `ezprofiler` escript, see...

  https://github.com/nhpip/ezprofiler.git

  https://hex.pm/packages/ezprofiler

  https://hexdocs.pm/ezprofiler/api-reference.html

  This module provides the ability to perform code profiling programmatically within an application rather than via the `ezprofiler` CLI.
  This maybe useful in environments where shell access maybe limited. Instead the output can be redirected to a logging subsystem for example.

  Use of this module still requires the `ezprofiler` escript, but it will be automatically initialized in the background.

  `ezprofiler` can be downloaded from https://github.com/nhpip/ezprofiler or added to `deps` in `mix.exs` along with this package:

      defp deps do
        [
          {:ezprofiler, git: "https://github.com/nhpip/ezprofiler.git"},
          {:ezprofiler_deps, git: "https://github.com/nhpip/ezprofiler_deps.git"}
        ]
      end

  This profiling mechanism supports two modes of operation, `synchronous` and `asynchronous`

  In synchronous mode the user starts profiling and then calls a blocking call to wait for the results.

  In asynchronous mode the results are sent as a message, this will be a `handle_info/2` in the case of a `GenServer`

  ## Synchronous Example

        EZProfiler.Manager.start_ezprofiler(%EZProfiler.Manager.Configure{ezprofiler_path: :deps})
        ...
        ...
        with :ok <- EZProfiler.Manager.enable_profiling(),
             :ok <- EZProfiler.Manager.wait_for_results(),
             {:ok, filename, results} <- EZProfiler.Manager.get_profiling_results(true)
        do
            {:ok, filename, results}
        else
          rsp ->
            rsp
        end
        ...
        ...
        EZProfiler.Manager.stop_ezprofiler()

  ## Asynchronous Example as a GenServer

        ## Your handle_cast
        def handle_cast(:start_profiling, state) do
          EZProfiler.Manager.start_ezprofiler(%EZProfiler.Manager.Configure{ezprofiler_path: :deps})
          EZProfiler.Manager.enable_profiling()
          EZProfiler.Manager.wait_for_results_non_block()
          {:noreply, state}
        end

        def handle_info({:ezprofiler, :results_available, label, filename, results}, state) do
          EZProfiler.Manager.stop_ezprofiler()
          do_something_with_results(filename, results)
          {:noreply, state}
        end

        def handle_info({:ezprofiler, :results_available}, state) do
          {:ok, filename, results} = EZProfiler.Manager.get_profiling_results(true)
          EZProfiler.Manager.stop_ezprofiler()
          {:noreply, state}
        end

        def handle_info({:ezprofiler, :timeout}, state) do
          # Ooops
          EZProfiler.Manager.stop_ezprofiler()
          {:noreply, state}
        end

  """

  defmodule Configure do

    @moduledoc """
    The configuration struct for code based code-profiling.

    """

    @type t :: %EZProfiler.Manager.Configure{node: String.t() | nil,
                                             cookie: String.t() | nil,
                                             mf: String.t(),
                                             directory: String.t(),
                                             profiler: String.t(),
                                             sort: String.t(),
                                             cpfo: String.t() | boolean(),
                                             labeltran: boolean(),
                                             ezprofiler_path: String.t() | atom()}

    defstruct [
      node: nil,
      cookie: nil,
      mf: "_:_",
      directory: "/tmp/",
      profiler: "eprof",
      sort: "mfa",
      cpfo: "false",
      labeltran: "false",
      ezprofiler_path: :system
    ]

  end

  alias EZProfiler.Manager.Configure

  @type display :: boolean()
  @type filename :: String.t()
  @type profile_data :: String.t()
  @type wait_time :: integer()
  @type profiling_cfg :: Configure.t()
  @type label :: atom() | String.t() | list()
  @type self :: pid()

  @doc """
  Starts and configures the `ezprofiler` escript. Takes the `%EZProfiler.Manager.Configure{}` struct as configuration.

  Most fields map directly onto the equivalent arguments for starting `ezprofiler`.

  The exception to this is `ezprofiler_path` that takes the following options:

        :system - if `ezprofiler` is defined via the `PATH` env variable.
        :deps - if `ezprofiler` is included as an application in `mix.ezs`
        path - a string specifying the full path for `ezprofiler`

  ## Example

        %EZProfiler.Manager.Configure{
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
  @spec start_ezprofiler(profiling_cfg()) :: {:ok, :started} | {:error, :timeout} | {:error, :not_started}
  def start_ezprofiler(profiling_cfg = %Configure{} \\ %Configure{}) do
    Code.ensure_loaded(__MODULE__)

    Map.from_struct(profiling_cfg)
    |> Map.replace!(:node, (if is_nil(profiling_cfg.node), do: node() |> Atom.to_string(), else: profiling_cfg.node))
    |> Map.replace!(:ezprofiler_path, find_ezprofiler(profiling_cfg.ezprofiler_path))
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
  def stop_ezprofiler() do
    Kernel.apply(EZProfiler.ProfilerOnTarget, :stop_profiling, [node()])
    do_stop_ezprofiler(length(Node.list()), 3)
  end

  @doc """
  Enables code profiling. The equivalent of hitting `c` or `c label` in the CLI.

  """
  @spec enable_profiling(label() | none()) :: :ok
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
  @spec wait_for_results(wait_time() | 60) :: :ok | {:error, :timeout}
  def wait_for_results(wait_time \\ 60) do
    timeout = wait_time * 1000
    receive do
      :results_available -> :ok
      :pseudo_results_available -> :ok
    after
      timeout -> {:error, :timeout}
    end
  end

  @doc """
  If many labels are specified in `enable_profiling/1` setting this to `true` will automatically re-enable profiling
  after one label has been profiled.

  ## Example

        enable_profiling(["L1", "L2", "L3"])

  L1 is hit and profiled it will be the equivalent of issuing:

        enable_profiling(["L2", "L3"])

  Then `L2` hit:

          enable_profiling(["L3"])

  This permits profiling a flow that may involve messages between a number of processes.

  """
  @spec allow_label_transition(boolean()) :: :ok
  def allow_label_transition(allow?) when is_boolean(allow?), do:
    Kernel.apply(EZProfiler.ProfilerOnTarget, :allow_label_transition, [node(), allow?])


  @doc """
  This is an asynchronous version of `wait_for_results/1`. This will cause a message to be sent to the process id specified as the first argument.

  If no pid is specified the result is sent to `self()`

  Three messages can be received:

      {:ezprofiler, :results_available, label, filename, results}
      {:ezprofiler, :results_available}  # Needs to call `get_profiling_results/1`
      {:ezprofiler, :timeout}

  In the case of a `GenServer` these will be received by `handle_info/2`

  """
  @spec wait_for_results_non_block(pid() | self(), wait_time() | 60) :: :ok
  def wait_for_results_non_block(pid \\ nil, wait_time \\ 60) do
    pid = if pid, do: pid, else: self()
    Kernel.apply(EZProfiler.ProfilerOnTarget, :change_code_manager_pid, [node(), pid])
  end

  @doc """
  Returns the resulting code profiling results. If the option `display` is set to true it will also output the `stdout`.

  On success it will return the tuple `{:ok, filename, result_string}`

  """
  @spec get_profiling_results(display() | false) :: {:ok, filename(), profile_data()} | {:error, atom()}
  def get_profiling_results(display \\ false) do
    case Kernel.apply(EZProfiler.ProfilerOnTarget, :get_latest_results, [node()]) do
      {:profiling_results, results} ->
        if display,
           do: for {_label, file, res} <- results,
               do: IO.puts("\nFile: #{inspect(file)}\n#{res}")
        {:ok, results}
      {:no_profiling_results, error} ->
        {:error, error}
    end
  end

  defp do_start_profiler({profiler_path, opts}) do
    pid = self()
    ezpid = spawn(fn ->
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
      {__MODULE__, rsp} ->
        :persistent_term.put(:ezprofiler_pid, ezpid)
        rsp
    after
      5000 ->
        {:error, :timeout}
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

  defp make_opt({:labeltran, v}) when v in [true, "true"], do:
    ["--labeltran"]

  defp make_opt({:labeltran, _v}), do:
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

  defp do_stop_ezprofiler(_nodes, 0), do:
    :ok

  defp do_stop_ezprofiler(0, _), do:
    :ok

  defp do_stop_ezprofiler(nodes, count) do
    Process.sleep(1000)
    length(Node.list()) != nodes || do_stop_ezprofiler(nodes, count - 1)
  end


end
