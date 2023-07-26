defmodule LiveQuery do
  @moduledoc """
  LiveQuery allows you to declare how to load, invalidate, and reload your data independently from your consumer logic.
  An example is going to help a lot here.

  Imagine you have a list of users in your database, and one or more consumers in your system want to "use" this list of users.
  I'm saying "use" to because it could mean a lot of things.
  Maybe you want to display the list of users in live view.
  Maybe you want return the list as a response to an API call.
  Maybe you just want to log them.
  LiveQuery doesn't care.

  Regardless, before you can consume a query you must define it.
  A query definition (def) can take a lot of forms, but for now we'll just write it in a module.

  ```elixir
  defmodule Users do
    use LiveQuery.Query.Def

    @impl true
    def init(_ctx) do
      Repo.all(User)
    end
  end
  ```

  This is enough to get started, but since we want a "live" user's list we'll also need to define how to subscribe to updates and reload our list in response to those updates.

  ```elixir
  defmodule Demo.Users do
    use LiveQuery.Query.Def

    @impl true
    def init(_ctx) do
      Phoenix.PubSub.subscribe(Demo.PubSub, "users")
      Repo.all(User)
    end

    @impl true
    def handle_info(_msg, _from, _ctx) do
      Repo.all(User)
    end
  end
  ```

  Again, notice that this definition is consumer agnostic.
  It says how to load a live user's list, but it doesn't care how you use it.
  So, now let's use it.
  How about from a Phoenix controller?

  ```elixir
  def DemoWeb.UsersController do
    use MyAppWeb, :controller

    def index(conn, _params) do
      LiveQuery.link(Demo.LiveQuery,
        query_key: [:users],
        query_def: Demo.Users,
        query_config: %{},
        client_pid: self()
      )

      users = LiveQuery.read(Demo.LiveQuery, query_key: [:users]).value
      render(conn, :index, users: users)
    end
  end
  ```

  This will almost work, but we need to make one more change.
  LiveQuery actually runs your queries for you, so you need to start it as part of your application.

  ```elixir
  def Demo.Supervisor do
    ...

    @impl true
    def init(_opts) do
      children = [
        ...
        {LiveQuery, name: Demo.LiveQuery},
        ...
      ]

      ...
    end
  end
  ```

  Now when someone visits the users index page, and the controller's index action is invoked our users list will be returned.
  What's cool is that this list will only exist at most once in memory at any given time.
  So, if lots of people visit the users index page at the same time, we don't have to worry about excess load on our database, or excess memory usage in our application.

  Now, you might say, this is fine, but it seems like the controller is doing a lot of work just to get a list of users.
  This is where LiveQuery client libraries come in.
  LiveQuery is consumer agnostic which is part of what makes it so powerful. You can write a query definition once, and then use it anywhere.
  However, it also means that you have to write a lot of boilerplate when you consume queries.
  Client libraries hide this boilerplate behind a simple API designed for a given consumer.

  Using LiveQuery.Client (coming soon) we can rewrite our controller like this:

  ```elixir
  def DemoWeb.UsersController do
    use MyAppWeb, :controller

    def index(conn, _params) do
      users = LiveQuery.Client.fetch!(Demo.LiveQuery, query_def: Demo.Users)
      render(conn, :index, users: users)
    end
  end
  ```

  This is much simpler, and you still get all the reuse and generalization benefits of LiveQuery.

  Hopefully, this example has given you a taste of what LiveQuery can do.
  You can explore individual function and module documentation for more details.
  """

  @doc """
  Used when running LiveQuery underneath a supervisor. Works the same way GenServer.child_spec/1 does.
  """

  defdelegate child_spec(opts), to: LiveQuery.Supervisor

  @doc """
  Starts a LiveQuery.

  - `:opts` - options concerning the query being linked
    - `:name` - the name of the LiveQuery system
  """
  defdelegate start_link(opts), to: LiveQuery.Supervisor

  @doc """
  Link a client process to a query.
  If the query process is not running, it will be started, but not initialized (that only happens once a client tries to read the query).
  Once at least one client process is linked to a query, you can rely on the query existing until all client processes are unlink from it.
  If you link a client process to a query and the client processes dies, the query will be unlinked from the client process automatically.

  - `:name` - the name of the LiveQuery system
  - `:opts` - options concerning the query being linked
    - `:query_key` - the key used to identify the query in the LiveQuery system
    - `:query_def` - the query definition (can be anything that implements the `LiveQuery.Query.DefLike` protocol)
    - `:query_config` - configuration for the query
    - `:client_pid` - the pid of the process that is linking to the query (usually yourself)
  """
  def link(name, opts) do
    GenServer.call(
      {:via, PartitionSupervisor, {name, opts[:query_key]}},
      LiveQuery.Protocol.Link.new(opts)
    )
  end

  @doc """
  Unlink a client process from a query.
  If the query has no more clients, it will be stopped.
  Unlinking a client process from a query that it is not already linked to is a no-op.

  - `:name` - the name of the LiveQuery system
  - `:opts` - options concerning the query being linked
    - `:query_key` - the key used to identify the query in the LiveQuery system
    - `:client_pid` - the pid of the process that is linking to the query (usually yourself)
  """
  def unlink(name, opts) do
    GenServer.call(
      {:via, PartitionSupervisor, {name, opts[:query_key]}},
      LiveQuery.Protocol.Unlink.new(opts)
    )
  end

  @doc """
  Read the value of a query.
  If the query is not running, a `LiveQuery.Protocol.NoQuery` struct will be returned.
  If the query is running, a `LiveQuery.Protocol.Data` struct will be returned.
  If the query hasn't yet been initialized, it will be initialized before returning the value.

  - `:name` - the name of the LiveQuery system
  - `:opts` - options concerning the query being linked
    - `:query_key` - the key used to identify the query in the LiveQuery system
    - `:selector` - the function used to transform the query's value before returning it
  """
  def read(name, opts) do
    GenServer.call(
      {:via, PartitionSupervisor, {name, opts[:query_key]}},
      LiveQuery.Protocol.Read.new(opts)
    )
  end

  @doc """
  Register a callback to be invoked with a `LiveQuery.Protocol.DataChanged` struct when a query's value changes.
  If the query is not running, a `LiveQuery.Protocol.NoQuery` struct will be returned.
  Callbacks allow consumers to inject logic into the query's lifecycle.
  Commonly this is used to have the query notify the consumer when it's value changes.
  All registered callbacks are automatically unregistered when their client process is unlinked.

  - `:name` - the name of the LiveQuery system
  - `:opts` - options concerning the query being linked
    - `:query_key` - the key used to identify the query in the LiveQuery system
    - `:client_pid` - the client process that is registering the callback (usually yourself)
    - `:cb_key` - uniquely identifies the callback so it can later be removed
    - `:cb` - the function to be invoked when the query's value changes
  """
  def register_callback(name, opts) do
    GenServer.call(
      {:via, PartitionSupervisor, {name, opts[:query_key]}},
      LiveQuery.Protocol.RegisterCallback.new(opts)
    )
  end

  @doc """
  Unregister a callback from a query.
  If the query is not running, a `LiveQuery.Protocol.NoQuery` struct will be returned.

  - `:name` - the name of the LiveQuery system
  - `:opts` - options concerning the query being linked
    - `:query_key` - the key used to identify the query in the LiveQuery system
    - `:client_pid` - the client process that is registering the callback (usually yourself)
    - `:cb_key` - uniquely identifies the callback (passed in when the query was registered)
  """
  def unregister_callback(name, opts) do
    GenServer.call(
      {:via, PartitionSupervisor, {name, opts[:query_key]}},
      LiveQuery.Protocol.UnregisterCallback.new(opts)
    )
  end

  @doc """
  Unregisters all callbacks from a query for a given client process.
  Identical to calling `unregister_callback/2` for all callbacks that have been registered for a given client process.

  - `:name` - the name of the LiveQuery system
  - `:opts` - options concerning the query being linked
    - `:query_key` - the key used to identify the query in the LiveQuery system
    - `:client_pid` - the client process that is registering the callback (usually yourself)
  """
  def unregister_all_callbacks(name, opts) do
    GenServer.call(
      {:via, PartitionSupervisor, {name, opts[:query_key]}},
      LiveQuery.Protocol.UnregisterAllCallbacks.new(opts)
    )
  end
end
