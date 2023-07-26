defmodule LiveQuery.Internal.Read do
  @moduledoc false

  @enforce_keys [:query_key, :selector, :proxy_pid]
  defstruct [:query_key, :selector, :proxy_pid]
end
