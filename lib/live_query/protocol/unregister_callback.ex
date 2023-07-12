defmodule LiveQuery.Protocol.UnregisterCallback do
  @moduledoc """
  TODO
  """

  @enforce_keys [:query_key, :client_pid, :cb_key]
  defstruct [:query_key, :client_pid, :cb_key]

  @doc """
  TODO
  """
  def new(opts) do
    query_key = Access.fetch!(opts, :query_key)
    false = is_nil(query_key)

    client_pid = Access.fetch!(opts, :client_pid)
    true = is_pid(client_pid)

    cb_key = Access.fetch!(opts, :cb_key)
    false = is_nil(cb_key)

    %__MODULE__{query_key: query_key, client_pid: client_pid, cb_key: cb_key}
  end
end
