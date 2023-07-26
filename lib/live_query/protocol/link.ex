defmodule LiveQuery.Protocol.Link do
  @moduledoc """
  Link a client process to a query.
  Once linked to a query, the client will be monitored, and the query will be guaranteed to exist so long as the client is alive and has manually unlinked from the query.
  """

  @enforce_keys [:client_pid, :query_key, :query_def, :query_config]
  defstruct [:client_pid, :query_key, :query_def, :query_config]

  @doc """
  Create a new `LiveQuery.Protocol.Link` struct safely.
  This validates the created struct will be considered valid by LiveQuery.
  Prefer using this function over literal struct creation when possible.
  """
  def new(struct = %__MODULE__{}) do
    struct
  end

  def new(opts) do
    query_key = Access.fetch!(opts, :query_key)
    false = is_nil(query_key)

    query_def = Access.fetch!(opts, :query_def)
    LiveQuery.Query.DefLike.impl_for!(query_def)

    query_config = Access.fetch!(opts, :query_config)
    LiveQuery.ConfigLike.impl_for!(query_config)

    client_pid = Access.fetch!(opts, :client_pid)
    true = is_pid(client_pid)

    %__MODULE__{
      query_key: query_key,
      query_def: query_def,
      query_config: query_config,
      client_pid: client_pid
    }
  end
end
