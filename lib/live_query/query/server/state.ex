defmodule LiveQuery.Query.Server.State do
  @moduledoc false

  defstruct [:key, :def, :config, :data, :callbacks]

  def new(opts) do
    %__MODULE__{
      key: opts.key,
      def: opts.def,
      config: opts.config,
      data: :undefined,
      callbacks: %{}
    }
  end

  def read(state = %__MODULE__{}, selector) do
    state =
      set_data(
        state,
        case state.data do
          :undefined ->
            try do
              LiveQuery.Query.DefLike.init(
                state.def,
                to_ctx(state)
              )
            catch
              :throw, data -> data
              kind, value -> {kind, value}
            end

          data ->
            data
        end
      )

    {state, %LiveQuery.Internal.Data{query_key: state.key, value: selector.(state.data)}}
  end

  def register_callback(state = %__MODULE__{}, client_pid, cb_key, cb) do
    state =
      Map.update!(state, :callbacks, fn callbacks ->
        callbacks
        |> Map.put_new(client_pid, %{})
        |> Map.update!(client_pid, fn client_callbacks ->
          Map.put(client_callbacks, cb_key, cb)
        end)
      end)

    {state,
     %LiveQuery.Internal.CallbackRegistered{
       query_key: state.key,
       cb_key: cb_key,
       client_pid: client_pid
     }}
  end

  def unregister_callback(state = %__MODULE__{}, client_pid, cb_key) do
    state =
      Map.update!(state, :callbacks, fn callbacks ->
        callbacks =
          callbacks
          |> Map.put_new(client_pid, %{})
          |> Map.update!(client_pid, fn client_callbacks ->
            Map.delete(client_callbacks, cb_key)
          end)

        if map_size(callbacks[client_pid]) == 0 do
          Map.delete(callbacks, client_pid)
        else
          callbacks
        end
      end)

    {state,
     %LiveQuery.Internal.CallbackUnregistered{
       query_key: state.key,
       cb_key: cb_key,
       client_pid: client_pid
     }}
  end

  def unregister_all_callbacks(state = %__MODULE__{}, client_pid) do
    response =
      state.callbacks
      |> Map.get(client_pid, %{})
      |> Map.keys()
      |> Enum.map(fn cb_key ->
        %LiveQuery.Internal.CallbackUnregistered{
          query_key: state.key,
          cb_key: cb_key,
          client_pid: client_pid
        }
      end)

    state =
      Map.update!(state, :callbacks, fn callbacks ->
        Map.delete(callbacks, client_pid)
      end)

    {state, response}
  end

  def set_data(state = %__MODULE__{}, data) when data != :undefined do
    if data != state.data do
      Enum.each(state.callbacks, fn {client_pid, client_callbacks} ->
        Enum.each(client_callbacks, fn {cb_key, cb} ->
          try do
            cb.(%LiveQuery.Protocol.DataChanged{
              query_key: state.key,
              client_pid: client_pid,
              cb_key: cb_key,
              old_data: state.data,
              new_data: data
            })
          catch
            kind, value ->
              IO.warn("LiveQuery callback failed: #{inspect(kind)}: #{inspect(value)}")
          end
        end)
      end)
    end

    Map.put(state, :data, data)
  end

  def delegate_handle_call(state = %__MODULE__{}, msg, from) do
    try do
      LiveQuery.Query.DefLike.handle_call(
        state.def,
        msg,
        from,
        to_ctx(state)
      )
    catch
      :throw, data -> {:noreply, data}
      kind, value -> {:noreply, {kind, value}}
    end
  end

  def delegate_handle_cast(state = %__MODULE__{}, msg) do
    try do
      LiveQuery.Query.DefLike.handle_cast(
        state.def,
        msg,
        to_ctx(state)
      )
    catch
      :throw, data -> data
      kind, value -> {kind, value}
    end
  end

  def delegate_handle_info(state = %__MODULE__{}, msg) do
    try do
      LiveQuery.Query.DefLike.handle_info(
        state.def,
        msg,
        to_ctx(state)
      )
    catch
      :throw, data -> data
      kind, value -> {kind, value}
    end
  end

  defp to_ctx(state = %__MODULE__{}) do
    if state.data == :undefined do
      %{key: state.key, config: state.config}
    else
      %{key: state.key, config: state.config, data: state.data}
    end
  end
end
