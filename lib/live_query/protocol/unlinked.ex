defmodule LiveQuery.Protocol.Unlinked do
  @moduledoc """
  TODO
  """

  @enforce_keys [:query_key, :client_pid]
  defstruct [:query_key, :client_pid]
end
