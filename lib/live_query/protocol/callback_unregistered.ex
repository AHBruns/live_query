defmodule LiveQuery.Protocol.CallbackUnregistered do
  @moduledoc """
  TODO
  """

  @enforce_keys [:query_key, :client_pid, :cb_key]
  defstruct [:query_key, :client_pid, :cb_key]
end
