defmodule LiveQuery.Query.Server do
  @moduledoc false

  use GenServer

  alias LiveQuery.Query.Server.State

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def read(query_server, opts) do
    GenServer.call(query_server, %LiveQuery.Internal.Read{
      query_key: opts[:query_key],
      selector: opts[:selector]
    })
  end

  def register_callback(query_server, opts) do
    GenServer.call(query_server, %LiveQuery.Internal.RegisterCallback{
      query_key: opts[:query_key],
      client_pid: opts[:client_pid],
      cb_key: opts[:cb_key],
      cb: opts[:cb]
    })
  end

  def unregister_callback(query_server, opts) do
    GenServer.call(query_server, %LiveQuery.Internal.UnregisterCallback{
      query_key: opts[:query_key],
      client_pid: opts[:client_pid],
      cb_key: opts[:cb_key]
    })
  end

  def unregister_all_callbacks(query_server, opts) do
    GenServer.call(query_server, %LiveQuery.Internal.UnregisterAllCallbacks{
      query_key: opts[:query_key],
      client_pid: opts[:client_pid]
    })
  end

  @impl true
  def init(opts) do
    {:ok, State.new(opts)}
  end

  @impl true
  def handle_call(msg = %LiveQuery.Internal.Read{}, _from, state = %State{}) do
    {state, response} = State.read(state, msg.selector)
    {:reply, response, state}
  end

  def handle_call(msg = %LiveQuery.Internal.RegisterCallback{}, _from, state = %State{}) do
    {state, response} = State.register_callback(state, msg.client_pid, msg.cb_key, msg.cb)
    {:reply, response, state}
  end

  def handle_call(msg = %LiveQuery.Internal.UnregisterCallback{}, _from, state = %State{}) do
    {state, response} = State.unregister_callback(state, msg.client_pid, msg.cb_key)
    {:reply, response, state}
  end

  def handle_call(msg = %LiveQuery.Internal.UnregisterAllCallbacks{}, _from, state = %State{}) do
    {state, response} = State.unregister_all_callbacks(state, msg.client_pid)
    {:reply, response, state}
  end

  def handle_call(msg, from, state = %State{}) do
    result = State.delegate_handle_call(state, msg, from)

    state =
      State.set_data(
        state,
        case result do
          {:reply, _reply, data} -> data
          {:noreply, data} -> data
        end
      )

    case result do
      {:reply, reply, _data} -> {:reply, reply, state}
      {:noreply, _data} -> {:noreply, state}
    end
  end

  @impl true
  def handle_cast(msg, state = %State{}) do
    state = State.set_data(state, State.delegate_handle_cast(state, msg))
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state = %State{}) do
    state = State.set_data(state, State.delegate_handle_info(state, msg))
    {:noreply, state}
  end
end
