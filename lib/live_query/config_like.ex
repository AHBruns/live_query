defprotocol LiveQuery.ConfigLike do
  @moduledoc false

  @spec fetch!(t, any) :: any
  def fetch!(self, key)
end

defimpl LiveQuery.ConfigLike, for: Map do
  def fetch!(self, key) do
    Map.fetch!(self, key)
  end
end

defimpl LiveQuery.ConfigLike, for: Keyword do
  def fetch!(self, key) do
    Keyword.fetch!(self, key)
  end
end

defimpl LiveQuery.ConfigLike, for: Atom do
  def fetch!(self, key) do
    apply(self, key, [])
  end
end
