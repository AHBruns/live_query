defmodule LiveQuery do
  @moduledoc """
  TODO
  """

  @doc """
  TODO
  """
  defdelegate child_spec(opts), to: LiveQuery.Supervisor

  @doc """
  TODO
  """
  defdelegate start_link(opts), to: LiveQuery.Supervisor

  @doc """
  TODO
  """
  defdelegate link(name, opts), to: LiveQuery.Proxy.Server

  @doc """
  TODO
  """
  defdelegate unlink(name, opts), to: LiveQuery.Proxy.Server

  @doc """
  TODO
  """
  defdelegate read(name, opts), to: LiveQuery.Proxy.Server

  @doc """
  TODO
  """
  defdelegate register_callback(name, opts), to: LiveQuery.Proxy.Server

  @doc """
  TODO
  """
  defdelegate unregister_callback(name, opts), to: LiveQuery.Proxy.Server

  @doc """
  TODO
  """
  defdelegate unregister_all_callbacks(name, opts), to: LiveQuery.Proxy.Server
end
