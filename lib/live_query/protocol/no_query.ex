defmodule LiveQuery.Protocol.NoQuery do
  @moduledoc """
  Returned whenever a operation is attepted against a query that doesn't exist.
  The only exception is `LiveQuery.Protocol.Link` and `LiveQuery.Protocol.Unlink`.
  """

  @enforce_keys [:query_key]
  defstruct [:query_key]
end
