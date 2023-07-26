defmodule LiveQuery.Protocol.Linked do
  @moduledoc """
  Returned in response to a `LiveQuery.Protocol.Link` call.
  """

  @enforce_keys [:client_pid, :query_key]
  defstruct [:client_pid, :query_key]
end
