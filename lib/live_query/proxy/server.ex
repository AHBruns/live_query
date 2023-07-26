defmodule LiveQuery.Proxy.Server do
  @moduledoc false

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    {:ok, %{clients: %{}, queries: %{}, monitor_refs: %{}}}
  end

  @impl true
  def handle_call(msg = %LiveQuery.Protocol.Link{}, from, state) do
    state =
      case state.queries[msg.query_key][:state] do
        {:processing, _from} ->
          Map.update!(state, :queries, fn queries ->
            Map.update!(queries, msg.query_key, fn query ->
              Map.update!(query, :deferred_messages, fn deferred_messages ->
                deferred_messages ++ [{:link, msg, from}]
              end)
            end)
          end)

        _ ->
          link(state, msg, from)
      end

    {:noreply, state}
  end

  def handle_call(msg = %LiveQuery.Protocol.Unlink{}, from, state) do
    state =
      case state.queries[msg.query_key][:state] do
        {:processing, _from} ->
          Map.update!(state, :queries, fn queries ->
            Map.update!(queries, msg.query_key, fn query ->
              Map.update!(query, :deferred_messages, fn deferred_messages ->
                deferred_messages ++ [{:unlink, msg, from}]
              end)
            end)
          end)

        _ ->
          unlink(state, msg, from)
      end

    {:noreply, state}
  end

  def handle_call(msg = %LiveQuery.Protocol.Read{}, from, state) do
    case state.queries[msg.query_key][:state] do
      nil ->
        {:reply, %LiveQuery.Protocol.NoQuery{query_key: msg.query_key}, state}

      {:processing, _from} ->
        state =
          Map.update!(state, :queries, fn queries ->
            Map.update!(queries, msg.query_key, fn query ->
              Map.update!(query, :deferred_messages, fn deferred_messages ->
                deferred_messages ++ [{:start_read, msg, from}]
              end)
            end)
          end)

        {:noreply, state}

      _ ->
        state = start_read(state, msg, from)
        {:noreply, state}
    end
  end

  def handle_call(msg = %LiveQuery.Protocol.RegisterCallback{}, from, state) do
    case state.queries[msg.query_key][:state] do
      nil ->
        {:reply, %LiveQuery.Protocol.NoQuery{query_key: msg.query_key}, state}

      {:processing, _from} ->
        state =
          Map.update!(state, :queries, fn queries ->
            Map.update!(queries, msg.query_key, fn query ->
              Map.update!(query, :deferred_messages, fn deferred_messages ->
                deferred_messages ++ [{:register_callback, msg, from}]
              end)
            end)
          end)

        {:noreply, state}

      _ ->
        state = register_callback(state, msg, from)
        {:noreply, state}
    end
  end

  def handle_call(msg = %LiveQuery.Protocol.UnregisterCallback{}, from, state) do
    case state.queries[msg.query_key][:state] do
      nil ->
        {:reply, %LiveQuery.Protocol.NoQuery{query_key: msg.query_key}, state}

      {:processing, _from} ->
        state =
          Map.update!(state, :queries, fn queries ->
            Map.update!(queries, msg.query_key, fn query ->
              Map.update!(query, :deferred_messages, fn deferred_messages ->
                deferred_messages ++ [{:unregister_callback, msg, from}]
              end)
            end)
          end)

        {:noreply, state}

      _ ->
        state = unregister_callback(state, msg, from)
        {:noreply, state}
    end
  end

  def handle_call(msg = %LiveQuery.Protocol.UnregisterAllCallbacks{}, from, state) do
    case state.queries[msg.query_key][:state] do
      nil ->
        {:reply, %LiveQuery.Protocol.NoQuery{query_key: msg.query_key}, state}

      {:processing, _from} ->
        state =
          Map.update!(state, :queries, fn queries ->
            Map.update!(queries, msg.query_key, fn query ->
              Map.update!(query, :deferred_messages, fn deferred_messages ->
                deferred_messages ++ [{:unregister_all_callbacks, msg, from}]
              end)
            end)
          end)

        {:noreply, state}

      _ ->
        state = unregister_all_callbacks(state, msg, from)
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast(msg = %LiveQuery.Internal.Data{}, state) do
    {:processing, from} = state.queries[msg.query_key].state

    GenServer.reply(from, %LiveQuery.Protocol.Data{query_key: msg.query_key, value: msg.value})

    state =
      Map.update!(state, :queries, fn queries ->
        Map.update!(queries, msg.query_key, fn query ->
          Map.put(query, :state, :idle)
        end)
      end)

    state =
      Enum.reduce_while(
        state.queries[msg.query_key].deferred_messages,
        state,
        fn
          deferred_msg, state ->
            case state.queries[msg.query_key].state do
              {:processing, _from} ->
                {:halt, state}

              :idle ->
                {fun_name, opts, from} = deferred_msg

                state =
                  Map.update!(state, :queries, fn queries ->
                    Map.update!(queries, msg.query_key, fn query ->
                      Map.update!(
                        query,
                        :deferred_messages,
                        fn [^deferred_msg | deferred_messages] ->
                          deferred_messages
                        end
                      )
                    end)
                  end)

                state = apply(__MODULE__, fun_name, [state, opts, from])
                {:cont, state}
            end
        end
      )

    {:noreply, state}
  end

  @impl true
  def handle_info(msg = {:DOWN, ref, :process, _pid, _reason}, state) do
    state =
      if Map.has_key?(state.monitor_refs, ref) do
        Enum.reduce(
          state.clients[state.monitor_refs[ref]].query_keys,
          state,
          fn query_key, state ->
            case state.queries[query_key].state do
              {:processing, _from} ->
                Map.update!(state, :queries, fn queries ->
                  Map.update!(queries, query_key, fn query ->
                    Map.update!(query, :deferred_messages, fn deferred_messages ->
                      deferred_messages ++
                        [
                          {
                            :unlink,
                            %{query_key: query_key, client_pid: state.monitor_refs[ref]},
                            nil
                          }
                        ]
                    end)
                  end)
                end)

              _ ->
                unlink(
                  state,
                  %{client_pid: state.monitor_refs[ref], query_key: query_key}
                )
            end
          end
        )
      else
        IO.warn("unexpected DOWN message: #{inspect(msg)} received")
        state
      end

    {:noreply, state}
  end

  def start_read(state, opts, from) do
    :ok =
      GenServer.cast(
        state.queries[opts.query_key].query_pid,
        %LiveQuery.Internal.Read{
          query_key: opts.query_key,
          selector: opts.selector,
          proxy_pid: self()
        }
      )

    state =
      Map.update!(state, :queries, fn queries ->
        Map.update!(queries, opts.query_key, fn query ->
          Map.put(query, :state, {:processing, from})
        end)
      end)

    state
  end

  def link(state, opts, from) do
    # setup client if it hasn't already been setup
    state =
      unless Map.has_key?(state.clients, opts.client_pid) do
        monitor_ref = Process.monitor(opts.client_pid)

        state
        |> Map.update!(:clients, fn clients ->
          Map.put(clients, opts.client_pid, %{query_keys: MapSet.new(), monitor_ref: monitor_ref})
        end)
        |> Map.update!(:monitor_refs, fn monitor_refs ->
          Map.put(monitor_refs, monitor_ref, opts.client_pid)
        end)
      else
        state
      end

    # setup query if it hasn't already been setup
    state =
      unless Map.has_key?(state.queries, opts.query_key) do
        {:ok, pid} =
          LiveQuery.Query.Server.start_link(%{
            key: opts.query_key,
            def: opts.query_def,
            config: opts.query_config
          })

        Map.update!(state, :queries, fn queries ->
          Map.put(queries, opts.query_key, %{
            query_pid: pid,
            client_pids: MapSet.new(),
            query_def: opts.query_def,
            query_config: opts.query_config,
            state: :idle,
            deferred_messages: []
          })
        end)
      else
        state
      end

    # link client to query and vice versa
    state =
      state
      |> Map.update!(:queries, fn queries ->
        Map.update!(queries, opts.query_key, fn query ->
          Map.update!(query, :client_pids, fn client_pids ->
            MapSet.put(client_pids, opts.client_pid)
          end)
        end)
      end)
      |> Map.update!(:clients, fn clients ->
        Map.update!(clients, opts.client_pid, fn client ->
          Map.update!(client, :query_keys, fn query_keys ->
            MapSet.put(query_keys, opts.query_key)
          end)
        end)
      end)

    unless is_nil(from) do
      GenServer.reply(from, %LiveQuery.Protocol.Linked{
        query_key: opts.query_key,
        client_pid: opts.client_pid
      })
    end

    state
  end

  def unlink(state, opts, from \\ nil) do
    # unlink client from query and vice versa
    state =
      state
      |> Map.update!(:queries, fn queries ->
        if Map.has_key?(queries, opts.query_key) do
          Map.update!(queries, opts.query_key, fn query ->
            Map.update!(query, :client_pids, fn client_pids ->
              MapSet.delete(client_pids, opts.client_pid)
            end)
          end)
        else
          queries
        end
      end)
      |> Map.update!(:clients, fn clients ->
        if Map.has_key?(clients, opts.client_pid) do
          Map.update!(clients, opts.client_pid, fn client ->
            Map.update!(client, :query_keys, fn query_keys ->
              MapSet.delete(query_keys, opts.query_key)
            end)
          end)
        else
          clients
        end
      end)

    # teardown query if no clients are linked to it
    state =
      if MapSet.size(state.queries[opts.query_key][:client_pids] || MapSet.new()) == 0 do
        GenServer.call(
          state.queries[opts.query_key].query_pid,
          %LiveQuery.Internal.UnregisterAllCallbacks{
            query_key: opts.query_key,
            client_pid: opts.client_pid
          }
        )

        :ok = GenServer.stop(state.queries[opts.query_key].query_pid)

        Map.update!(state, :queries, fn queries -> Map.delete(queries, opts.query_key) end)
      else
        state
      end

    # teardown client if no queries are linked to it
    state =
      if MapSet.size(state.clients[opts.client_pid][:query_keys] || MapSet.new()) == 0 do
        Process.demonitor(state.clients[opts.client_pid].monitor_ref, [:flush])

        state
        |> Map.update!(:monitor_refs, fn monitor_refs ->
          Map.delete(monitor_refs, state.clients[opts.client_pid].monitor_ref)
        end)
        |> Map.update!(:clients, fn clients -> Map.delete(clients, opts.client_pid) end)
      else
        state
      end

    unless is_nil(from) do
      GenServer.reply(from, %LiveQuery.Protocol.Unlinked{
        query_key: opts.query_key,
        client_pid: opts.client_pid
      })
    end

    state
  end

  def register_callback(state, opts, from) do
    :ok =
      GenServer.cast(
        state.queries[opts.query_key].query_pid,
        %LiveQuery.Internal.RegisterCallback{
          query_key: opts.query_key,
          cb: opts.cb,
          cb_key: opts.cb_key,
          client_pid: opts.client_pid
        }
      )

    unless is_nil(from) do
      GenServer.reply(
        from,
        %LiveQuery.Protocol.CallbackRegistered{
          query_key: opts.query_key,
          client_pid: opts.client_pid,
          cb_key: opts.cb_key
        }
      )
    end

    state
  end

  def unregister_callback(state, opts, from) do
    :ok =
      GenServer.cast(
        state.queries[opts.query_key].query_pid,
        %LiveQuery.Internal.UnregisterCallback{
          query_key: opts.query_key,
          cb_key: opts.cb_key,
          client_pid: opts.client_pid
        }
      )

    unless is_nil(from) do
      GenServer.reply(
        from,
        %LiveQuery.Protocol.CallbackUnregistered{
          query_key: opts.query_key,
          cb_key: opts.cb_key,
          client_pid: opts.client_pid
        }
      )
    end

    state
  end

  def unregister_all_callbacks(state, opts, from) do
    resp =
      GenServer.call(
        state.queries[opts.query_key].query_pid,
        %LiveQuery.Internal.UnregisterAllCallbacks{
          query_key: opts.query_key,
          client_pid: opts.client_pid
        }
      )

    unless is_nil(from) do
      GenServer.reply(
        from,
        Enum.map(resp, fn %LiveQuery.Internal.CallbackUnregistered{} = resp ->
          %LiveQuery.Protocol.CallbackUnregistered{
            query_key: resp.query_key,
            client_pid: resp.client_pid,
            cb_key: resp.cb_key
          }
        end)
      )
    end

    state
  end
end
