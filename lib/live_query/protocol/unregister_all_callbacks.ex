defmodule LiveQuery.Protocol.UnregisterAllCallbacks do
  @moduledoc """
  TODO
  """

  @enforce_keys [:query_key, :client_pid]
  defstruct [:query_key, :client_pid]

  @doc """
  TODO
  """
  def new(opts) do
    query_key = Access.fetch!(opts, :query_key)
    false = is_nil(query_key)

    client_pid = Access.fetch!(opts, :client_pid)
    true = is_pid(client_pid)

    %__MODULE__{query_key: query_key, client_pid: client_pid}
  end
end
