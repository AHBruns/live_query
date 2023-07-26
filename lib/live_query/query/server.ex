defmodule LiveQuery.Query.Server do
  @moduledoc false

  use GenServer

  alias LiveQuery.Query.Server.State

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    {:ok, State.new(opts)}
  end

  @impl true
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
  def handle_cast(msg = %LiveQuery.Internal.Read{}, state = %State{}) do
    {state, response} = State.read(state, msg.selector)
    :ok = GenServer.cast(msg.proxy_pid, response)
    {:noreply, state}
  end

  def handle_cast(msg = %LiveQuery.Internal.RegisterCallback{}, state = %State{}) do
    state = State.register_callback(state, msg.client_pid, msg.cb_key, msg.cb)
    {:noreply, state}
  end

  def handle_cast(msg = %LiveQuery.Internal.UnregisterCallback{}, state = %State{}) do
    state = State.unregister_callback(state, msg.client_pid, msg.cb_key)
    {:noreply, state}
  end

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
