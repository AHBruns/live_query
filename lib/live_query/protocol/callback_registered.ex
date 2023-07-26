defmodule LiveQuery.Protocol.CallbackRegistered do
  @moduledoc """
  Sent in response to a `LiveQuery.Protocol.RegisterCallback` call.
  The callback's return value is discarded by the query.
  The `cb_key` is used to identify the callback when unregistering it. It is namespaced to the `client_pid`.
  That is, different clients can register callbacks with the same `cb_key` at the same time and they will not interfere with each other.
  """

  @enforce_keys [:query_key, :client_pid, :cb_key]
  defstruct [:query_key, :client_pid, :cb_key]
end
