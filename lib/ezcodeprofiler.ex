defmodule EZProfiler.CodeProfiler do
  @moduledoc """
  This module requires the `ezprofiler` escript, see...

  https://hexdocs.pm/ezprofiler/api-reference.html

  https://github.com/nhpip/ezprofiler.git

  https://hex.pm/packages/ezprofiler

  Please see documentation for `CodeProfiler` in `ezprofiler`.

  https://hexdocs.pm/ezprofiler/EZProfiler.CodeProfiler.html

  """

  @on_load :cleanup

  @doc false
  def cleanup() do
    if :code.module_status(__MODULE__) == :modified do
      spawn(fn ->
        Process.sleep(1000)
        :code.purge(EZProfiler.ProfilerOnTarget)
        :code.delete(EZProfiler.ProfilerOnTarget)
        :code.purge(EZProfiler.CodeMonitor)
        :code.delete(EZProfiler.CodeMonitor)
      end)
    end
    :ok
  end

  @doc false
  def start() do

  end

  @doc false
  def allow_profiling() do

  end

  @doc false
  def disallow_profiling() do

  end

  @doc false
  def start_code_profiling() do

  end

  @doc false
  def start_code_profiling(_label_or_fun) do

  end

  @doc false
  def function_profiling(fun) do
    Kernel.apply(fun, [])
  end

  @doc false
  def function_profiling(fun, args) when is_list(args) do
    Kernel.apply(fun, args)
  end

  @doc false
  def function_profiling(fun, _label_or_fun)  do
    Kernel.apply(fun, [])
  end

  @doc false
  def function_profiling(fun, args, _label_or_fun)  do
    Kernel.apply(fun, args)
  end

  @doc false
  def pipe_profiling(arg, fun) do
    Kernel.apply(fun, [arg])
  end

  @doc false
  def pipe_profiling(arg, fun, args) when is_list(args) do
    Kernel.apply(fun, [arg|args])
  end

  @doc false
  def pipe_profiling(arg, fun, _label_or_fun) do
    Kernel.apply(fun, [arg])
  end

  @doc false
  def pipe_profiling(arg, fun, args, _label_or_fun) do
    Kernel.apply(fun, [arg|args])
  end

  @doc false
  def stop_code_profiling() do

  end

  @doc false
  def get() do

  end

end
