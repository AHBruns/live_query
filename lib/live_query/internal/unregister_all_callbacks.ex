defmodule LiveQuery.Internal.UnregisterAllCallbacks do
  @moduledoc false

  @enforce_keys [:query_key, :client_pid]
  defstruct [:query_key, :client_pid]
end
