defmodule LiveQuery.Protocol.Data do
  @moduledoc """
  Returned in response to a `LiveQuery.Protocol.Read` call (when the query exists).
  """

  @enforce_keys [:query_key, :value]
  defstruct [:query_key, :value]
end
