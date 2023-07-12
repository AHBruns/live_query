defmodule LiveQuery.Proxy.Server do
  @moduledoc false

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def link(name, opts) do
    GenServer.call(
      {:via, PartitionSupervisor, {name, opts[:query_key]}},
      LiveQuery.Protocol.Link.new(opts)
    )
  end

  def unlink(name, opts) do
    GenServer.call(
      {:via, PartitionSupervisor, {name, opts[:query_key]}},
      LiveQuery.Protocol.Unlink.new(opts)
    )
  end

  def read(name, opts) do
    GenServer.call(
      {:via, PartitionSupervisor, {name, opts[:query_key]}},
      LiveQuery.Protocol.Read.new(opts)
    )
  end

  def register_callback(name, opts) do
    GenServer.call(
      {:via, PartitionSupervisor, {name, opts[:query_key]}},
      LiveQuery.Protocol.RegisterCallback.new(opts)
    )
  end

  def unregister_callback(name, opts) do
    GenServer.call(
      {:via, PartitionSupervisor, {name, opts[:query_key]}},
      LiveQuery.Protocol.UnregisterCallback.new(opts)
    )
  end

  def unregister_all_callbacks(name, opts) do
    GenServer.call(
      {:via, PartitionSupervisor, {name, opts[:query_key]}},
      LiveQuery.Protocol.UnregisterAllCallbacks.new(opts)
    )
  end

  @impl true
  def init(_opts) do
    {:ok,
     %{
       query_keys_to_query_server_pids: %{},
       query_keys_to_query_defs: %{},
       query_keys_to_query_configs: %{},
       query_keys_to_client_pids: %{},
       client_pids_to_query_keys: %{},
       client_pids_to_monitor_refs: %{}
     }}
  end

  @impl true
  def handle_call(msg = %LiveQuery.Protocol.Link{}, _from, state) do
    state =
      unless Map.has_key?(state.query_keys_to_query_server_pids, msg.query_key) do
        {:ok, pid} =
          LiveQuery.Query.Server.start_link(%{
            key: msg.query_key,
            def: msg.query_def,
            config: msg.query_config
          })

        state
        |> Map.update!(:query_keys_to_query_server_pids, fn query_keys_to_query_server_pids ->
          Map.put(query_keys_to_query_server_pids, msg.query_key, pid)
        end)
        |> Map.update!(:query_keys_to_query_defs, fn query_keys_to_query_defs ->
          Map.put(query_keys_to_query_defs, msg.query_key, msg.query_def)
        end)
        |> Map.update!(:query_keys_to_query_configs, fn query_keys_to_query_configs ->
          Map.put(query_keys_to_query_configs, msg.query_key, msg.query_config)
        end)
      else
        state
      end
      |> Map.update!(:client_pids_to_query_keys, fn client_pids_to_query_keys ->
        client_pids_to_query_keys
        |> Map.put_new(msg.client_pid, MapSet.new())
        |> Map.update!(msg.client_pid, fn query_keys ->
          MapSet.put(query_keys, msg.query_key)
        end)
      end)
      |> Map.update!(:query_keys_to_client_pids, fn query_keys_to_client_pids ->
        query_keys_to_client_pids
        |> Map.put_new(msg.query_key, MapSet.new())
        |> Map.update!(msg.query_key, fn client_pids ->
          MapSet.put(client_pids, msg.client_pid)
        end)
      end)
      |> Map.update!(:client_pids_to_monitor_refs, fn client_pids_to_monitor_refs ->
        Map.put_new_lazy(client_pids_to_monitor_refs, msg.client_pid, fn ->
          Process.monitor(msg.client_pid)
        end)
      end)

    {:reply, %LiveQuery.Protocol.Linked{query_key: msg.query_key, client_pid: msg.client_pid},
     state}
  end

  def handle_call(msg = %LiveQuery.Protocol.Unlink{}, _from, state) do
    state =
      if Map.has_key?(state.client_pids_to_query_keys, msg.client_pid) and
           Map.has_key?(state.query_keys_to_query_server_pids, msg.query_key) do
        state =
          if MapSet.equal?(
               state.query_keys_to_client_pids[msg.query_key],
               MapSet.new([msg.client_pid])
             ) do
            :ok = GenServer.stop(state.query_keys_to_query_server_pids[msg.query_key])

            state
            |> Map.update!(:query_keys_to_query_server_pids, fn query_keys_to_query_server_pids ->
              Map.delete(query_keys_to_query_server_pids, msg.query_key)
            end)
            |> Map.update!(:query_keys_to_query_defs, fn query_keys_to_query_defs ->
              Map.delete(query_keys_to_query_defs, msg.query_key)
            end)
            |> Map.update!(:query_keys_to_query_configs, fn query_keys_to_query_configs ->
              Map.delete(query_keys_to_query_configs, msg.query_key)
            end)
            |> Map.update!(:query_keys_to_client_pids, fn query_keys_to_client_pids ->
              Map.delete(query_keys_to_client_pids, msg.query_key)
            end)
          else
            # technically we could allow callbacks to unlinked servers, worth thinking about
            LiveQuery.Query.Server.unregister_all_callbacks(
              state.query_keys_to_query_server_pids[msg.query_key],
              query_key: msg.query_key,
              client_pid: msg.client_pid
            )

            state
            |> Map.update!(:query_keys_to_client_pids, fn query_keys_to_client_pids ->
              query_keys_to_client_pids
              |> Map.put_new(msg.query_key, MapSet.new())
              |> Map.update!(msg.query_key, fn client_pids ->
                MapSet.delete(client_pids, msg.client_pid)
              end)
            end)
          end

        if MapSet.equal?(
             state.client_pids_to_query_keys[msg.client_pid],
             MapSet.new([msg.query_key])
           ) do
          Process.demonitor(state.client_pids_to_monitor_refs[msg.client_pid], [:flush])

          state
          |> Map.update!(:client_pids_to_query_keys, fn client_pids_to_query_keys ->
            Map.delete(client_pids_to_query_keys, msg.client_pid)
          end)
          |> Map.update!(:client_pids_to_monitor_refs, fn client_pids_to_monitor_refs ->
            Map.delete(client_pids_to_monitor_refs, msg.client_pid)
          end)
        else
          Map.update!(state, :client_pids_to_query_keys, fn client_pids_to_query_keys ->
            Map.update!(client_pids_to_query_keys, msg.client_pid, fn query_keys ->
              MapSet.delete(query_keys, msg.query_key)
            end)
          end)
        end
      else
        state
      end

    {:reply, %LiveQuery.Protocol.Unlinked{query_key: msg.query_key, client_pid: msg.client_pid},
     state}
  end

  def handle_call(msg = %LiveQuery.Protocol.Read{}, _from, state) do
    if Map.has_key?(state.query_keys_to_query_server_pids, msg.query_key) do
      resp =
        %LiveQuery.Internal.Data{} =
        LiveQuery.Query.Server.read(
          state.query_keys_to_query_server_pids[msg.query_key],
          query_key: msg.query_key,
          selector: msg.selector
        )

      {:reply, %LiveQuery.Protocol.Data{query_key: msg.query_key, value: resp.value}, state}
    else
      {:reply, %LiveQuery.Protocol.NoQuery{query_key: msg.query_key}, state}
    end
  end

  def handle_call(msg = %LiveQuery.Protocol.RegisterCallback{}, _from, state) do
    if Map.has_key?(state.query_keys_to_query_server_pids, msg.query_key) do
      resp =
        %LiveQuery.Internal.CallbackRegistered{} =
        LiveQuery.Query.Server.register_callback(
          state.query_keys_to_query_server_pids[msg.query_key],
          query_key: msg.query_key,
          cb: msg.cb,
          cb_key: msg.cb_key,
          client_pid: msg.client_pid
        )

      {:reply,
       %LiveQuery.Protocol.CallbackRegistered{
         query_key: resp.query_key,
         client_pid: resp.client_pid,
         cb_key: resp.cb_key
       }, state}
    else
      {:reply, %LiveQuery.Protocol.NoQuery{query_key: msg.query_key}, state}
    end
  end

  def handle_call(msg = %LiveQuery.Protocol.UnregisterCallback{}, _from, state) do
    if Map.has_key?(state.query_keys_to_query_server_pids, msg.query_key) do
      resp =
        %LiveQuery.Internal.CallbackUnregistered{} =
        LiveQuery.Query.Server.unregister_callback(
          state.query_keys_to_query_server_pids[msg.query_key],
          query_key: msg.query_key,
          cb_key: msg.cb_key,
          client_pid: msg.client_pid
        )

      {:reply,
       %LiveQuery.Protocol.CallbackUnregistered{
         query_key: resp.query_key,
         client_pid: resp.client_pid,
         cb_key: resp.cb_key
       }, state}
    else
      {:reply, %LiveQuery.Protocol.NoQuery{query_key: msg.query_key}, state}
    end
  end

  def handle_call(msg = %LiveQuery.Protocol.UnregisterAllCallbacks{}, _from, state) do
    if Map.has_key?(state.query_keys_to_query_server_pids, msg.query_key) do
      resp =
        LiveQuery.Query.Server.unregister_all_callbacks(
          state.query_keys_to_query_server_pids[msg.query_key],
          query_key: msg.query_key,
          client_pid: msg.client_pid
        )

      {:reply,
       Enum.map(resp, fn %LiveQuery.Internal.CallbackUnregistered{} = resp ->
         %LiveQuery.Protocol.CallbackUnregistered{
           query_key: resp.query_key,
           client_pid: resp.client_pid,
           cb_key: resp.cb_key
         }
       end), state}
    else
      {:reply, %LiveQuery.Protocol.NoQuery{query_key: msg.query_key}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    state =
      if state.client_pids_to_monitor_refs[pid] == ref do
        Enum.reduce(state.client_pids_to_query_keys[pid], state, fn query_key, state ->
          {:reply, _, state} =
            handle_call(
              %LiveQuery.Protocol.Unlink{client_pid: pid, query_key: query_key},
              nil,
              state
            )

          state
        end)
      else
        IO.warn(
          "unexpected DOWN message: #{inspect({:DOWN, ref, :process, pid, reason})} received"
        )

        state
      end

    {:noreply, state}
  end
end
