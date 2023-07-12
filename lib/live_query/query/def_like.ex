defprotocol LiveQuery.Query.DefLike do
  @moduledoc """
  TODO
  """

  @type data :: any

  @doc """
  TODO
  """
  @spec init(
          self :: t,
          state :: %{required(:key) => any, required(:config) => map}
        ) :: data
  def init(self, state)

  @doc """
  TODO
  """
  @spec handle_call(
          self :: t,
          msg :: any,
          from :: GenServer.from(),
          state :: %{required(:key) => any, required(:config) => map, optional(:data) => data}
        ) :: {:noreply, data} | {:reply, any, data}
  def handle_call(self, msg, from, state)

  @doc """
  TODO
  """
  @spec handle_cast(
          self :: t,
          msg :: any,
          state :: %{required(:key) => any, required(:config) => map, optional(:data) => data}
        ) :: data
  def handle_cast(self, msg, state)

  @doc """
  TODO
  """
  @spec handle_info(
          self :: t,
          msg :: any,
          state :: %{required(:key) => any, required(:config) => map, optional(:data) => data}
        ) :: data
  def handle_info(self, msg, state)
end

defimpl LiveQuery.Query.DefLike, for: Atom do
  def init(self, state) do
    self.init(state)
  end

  def handle_call(self, msg, from, state) do
    self.handle_call(msg, from, state)
  end

  def handle_cast(self, msg, state) do
    self.handle_cast(msg, state)
  end

  def handle_info(self, msg, state) do
    self.handle_info(msg, state)
  end
end

defimpl LiveQuery.Query.DefLike, for: Function do
  def init(self, state) do
    self.(state)
  end

  def handle_call(_self, _msg, _from, _state) do
    raise "handle_call/3 not implemented"
  end

  def handle_cast(_self, _msg, _state) do
    raise "handle_cast/2 not implemented"
  end

  def handle_info(_self, _msg, _state) do
    raise "handle_info/2 not implemented"
  end
end

defimpl LiveQuery.Query.DefLike, for: [Map, List] do
  def init(self, state) do
    self[:init].(state)
  end

  def handle_call(self, msg, from, state) do
    self[:handle_call].(msg, from, state)
  end

  def handle_cast(self, msg, state) do
    self[:handle_cast].(msg, state)
  end

  def handle_info(self, msg, state) do
    self[:handle_info].(msg, state)
  end
end
