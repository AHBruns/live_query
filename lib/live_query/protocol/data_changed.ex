defmodule LiveQuery.Protocol.DataChanged do
  @moduledoc """
  Given to a callback when the data for a query changes.
  """

  @enforce_keys [:query_key, :client_pid, :cb_key, :old_data, :new_data]
  defstruct [:query_key, :client_pid, :cb_key, :old_data, :new_data]
end
