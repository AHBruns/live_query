defmodule LiveQuery.Protocol.Linked do
  @moduledoc """
  TODO
  """

  @enforce_keys [:client_pid, :query_key]
  defstruct [:client_pid, :query_key]
end
