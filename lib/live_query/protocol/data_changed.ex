defmodule LiveQuery.Protocol.DataChanged do
  @moduledoc """
  TODO
  """

  @enforce_keys [:query_key, :client_pid, :cb_key, :old_data, :new_data]
  defstruct [:query_key, :client_pid, :cb_key, :old_data, :new_data]
end
