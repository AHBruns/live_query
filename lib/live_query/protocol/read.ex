defmodule LiveQuery.Protocol.Read do
  @moduledoc """
  Read the value of a query (the query's init function will be called if it hasn't been called yet).
  The `selector` function will be called with the query's value and before the result is returned.
  """

  @enforce_keys [:query_key, :selector]
  defstruct [:query_key, :selector]

  @doc """
  Create a new `LiveQuery.Protocol.Read` struct.
  If `selector` is not provided the indentity function will be used by default.
  """
  def new(struct = %__MODULE__{}) do
    struct
  end

  def new(opts) do
    query_key = Access.fetch!(opts, :query_key)
    false = is_nil(query_key)

    selector = Access.get(opts, :selector, fn v -> v end)
    true = is_function(selector, 1)

    %__MODULE__{
      query_key: query_key,
      selector: selector
    }
  end
end
