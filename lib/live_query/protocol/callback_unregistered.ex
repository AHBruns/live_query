defmodule LiveQuery.Protocol.CallbackUnregistered do
  @moduledoc """
  Sent in response to a `LiveQuery.Protocol.UnegisterCallback` call.
  Additionally, a list of these are returned in response to a `LiveQuery.Protocol.UnegisterAllCallbacks` call.
  The `cb_key` is the same one used to identify the callback when registering it.
  """

  @enforce_keys [:query_key, :client_pid, :cb_key]
  defstruct [:query_key, :client_pid, :cb_key]
end
