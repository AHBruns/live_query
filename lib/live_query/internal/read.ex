defmodule LiveQuery.Internal.Read do
  @moduledoc false

  @enforce_keys [:query_key, :selector]
  defstruct [:query_key, :selector]
end
