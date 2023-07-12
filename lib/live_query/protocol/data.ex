defmodule LiveQuery.Protocol.Data do
  @moduledoc """
  TODO
  """

  @enforce_keys [:query_key, :value]
  defstruct [:query_key, :value]
end
