defmodule LiveQuery.Internal.CallbackUnregistered do
  @moduledoc false

  @enforce_keys [:query_key, :client_pid, :cb_key]
  defstruct [:query_key, :client_pid, :cb_key]
end
