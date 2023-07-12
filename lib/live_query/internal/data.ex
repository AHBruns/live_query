defmodule LiveQuery.Internal.Data do
  @moduledoc false

  @enforce_keys [:query_key, :value]
  defstruct [:query_key, :value]
end
