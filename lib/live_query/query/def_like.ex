defprotocol LiveQuery.Query.DefLike do
  @moduledoc """
  A query definition defines how to load and maintain a query.
  It's the blueprint of a query.
  Anything that implements the `LiveQuery.Query.DefLike` protocol can be used as a query definition.
  """

  @type data :: any

  @doc """
  Called when the query is initialized.
  This is where the query should be loaded and any subscriptions should be setup.
  """
  @spec init(
          self :: t,
          state :: %{required(:key) => any, required(:config) => map}
        ) :: data
  def init(self, state)

  @doc """
  Your query process is like a GenServer.
  You can handle calls, but you're limited in what you can return since queries don't allow for handle_continue.
  """
  @spec handle_call(
          self :: t,
          msg :: any,
          from :: GenServer.from(),
          state :: %{required(:key) => any, required(:config) => map, optional(:data) => data}
        ) :: {:noreply, data} | {:reply, any, data}
  def handle_call(self, msg, from, state)

  @doc """
  Your query process is like a GenServer.
  You can handle casts, but you're limited in what you can return since queries don't allow for handle_continue.
  You must return your query's new value.
  """
  @spec handle_cast(
          self :: t,
          msg :: any,
          state :: %{required(:key) => any, required(:config) => map, optional(:data) => data}
        ) :: data
  def handle_cast(self, msg, state)

  @doc """
  Your query process is like a GenServer.
  You can handle messages, but you're limited in what you can return since queries don't allow for handle_continue.
  You must return your query's new value.
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
