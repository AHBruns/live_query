defmodule LiveQuery.Protocol.RegisterCallback do
  @moduledoc """
  TODO
  """

  @enforce_keys [:query_key, :client_pid, :cb_key, :cb]
  defstruct [:query_key, :client_pid, :cb_key, :cb]

  @doc """
  TODO
  """
  def new(struct = %__MODULE__{}) do
    struct
  end

  def new(opts) do
    query_key = Access.fetch!(opts, :query_key)
    false = is_nil(query_key)

    client_pid = Access.fetch!(opts, :client_pid)
    true = is_pid(client_pid)

    cb_key = Access.fetch!(opts, :cb_key)
    false = is_nil(cb_key)

    cb = Access.fetch!(opts, :cb)
    true = is_function(cb, 1)

    %__MODULE__{
      query_key: query_key,
      client_pid: client_pid,
      cb_key: cb_key,
      cb: cb
    }
  end
end
