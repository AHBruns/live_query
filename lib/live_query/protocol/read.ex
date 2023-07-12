defmodule LiveQuery.Protocol.Read do
  @moduledoc """
  TODO
  """

  @enforce_keys [:query_key, :selector]
  defstruct [:query_key, :selector]

  @doc """
  TODO
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
