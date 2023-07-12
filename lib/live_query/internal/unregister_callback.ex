defmodule LiveQuery.Internal.UnregisterCallback do
  @moduledoc false

  @enforce_keys [:query_key, :client_pid, :cb_key]
  defstruct [:query_key, :client_pid, :cb_key]
end
