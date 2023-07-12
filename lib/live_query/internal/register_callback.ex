defmodule LiveQuery.Internal.RegisterCallback do
  @moduledoc false

  @enforce_keys [:query_key, :client_pid, :cb_key, :cb]
  defstruct [:query_key, :client_pid, :cb_key, :cb]
end
