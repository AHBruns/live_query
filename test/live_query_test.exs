defmodule LiveQueryTest do
  use ExUnit.Case, async: true

  setup ctx do
    name = ctx[:module]
    start_link_supervised!({LiveQuery, name: name})
    query_key = [:test]
    proxy_server = {:via, PartitionSupervisor, {name, query_key}}
    {:ok, name: name, query_key: query_key, proxy_server: proxy_server}
  end

  test "linking mutates the proxy server's state", ctx do
    original_state = :sys.get_state(ctx[:proxy_server])

    LiveQuery.link(ctx[:name],
      query_key: ctx[:query_key],
      query_def: fn _ctx -> :success end,
      query_config: %{},
      client_pid: self()
    )

    assert :sys.get_state(ctx[:proxy_server]) != original_state
  end

  test "unlinking is the exact inverse of linking wrt the proxy sever's state", ctx do
    original_state = :sys.get_state(ctx[:proxy_server])

    LiveQuery.link(ctx[:name],
      query_key: ctx[:query_key],
      query_def: fn _ctx -> :success end,
      query_config: %{},
      client_pid: self()
    )

    LiveQuery.unlink(ctx[:name],
      query_key: ctx[:query_key],
      client_pid: self()
    )

    assert :sys.get_state(ctx[:proxy_server]) == original_state
  end

  test "reading an non-running query returns no-query", ctx do
    assert LiveQuery.read(ctx[:name], query_key: ctx[:query_key]) ==
             %LiveQuery.Protocol.NoQuery{query_key: ctx[:query_key]}
  end

  test "reading a running query returns data", ctx do
    LiveQuery.link(ctx[:name],
      query_key: ctx[:query_key],
      query_def: fn _ctx -> :success end,
      query_config: %{},
      client_pid: self()
    )

    assert LiveQuery.read(ctx[:name], query_key: ctx[:query_key]) ==
             %LiveQuery.Protocol.Data{query_key: ctx[:query_key], value: :success}
  end

  test "reading a previously running query returns no-query", ctx do
    LiveQuery.link(ctx[:name],
      query_key: ctx[:query_key],
      query_def: fn _ctx -> :success end,
      query_config: %{},
      client_pid: self()
    )

    LiveQuery.unlink(ctx[:name],
      query_key: ctx[:query_key],
      client_pid: self()
    )

    assert LiveQuery.read(ctx[:name], query_key: ctx[:query_key]) ==
             %LiveQuery.Protocol.NoQuery{query_key: ctx[:query_key]}
  end

  test "registering a callback to a non-running query returns no-query", ctx do
    assert LiveQuery.register_callback(ctx[:name],
             query_key: ctx[:query_key],
             client_pid: self(),
             cb_key: [],
             cb: fn _ -> :ignore end
           ) == %LiveQuery.Protocol.NoQuery{query_key: ctx[:query_key]}
  end

  test "registering a callback to a previous running query returns no-query", ctx do
    LiveQuery.link(ctx[:name],
      query_key: ctx[:query_key],
      query_def: fn _ctx -> :success end,
      query_config: %{},
      client_pid: self()
    )

    LiveQuery.unlink(ctx[:name],
      query_key: ctx[:query_key],
      client_pid: self()
    )

    assert LiveQuery.register_callback(ctx[:name],
             query_key: ctx[:query_key],
             client_pid: self(),
             cb_key: [],
             cb: fn _ -> :ignore end
           ) == %LiveQuery.Protocol.NoQuery{query_key: ctx[:query_key]}
  end

  test "registering a callback to a running query returns callback registered", ctx do
    LiveQuery.link(ctx[:name],
      query_key: ctx[:query_key],
      query_def: fn _ctx -> :success end,
      query_config: %{},
      client_pid: self()
    )

    cb = fn _ -> :ignore end

    assert LiveQuery.register_callback(ctx[:name],
             query_key: ctx[:query_key],
             client_pid: self(),
             cb_key: [],
             cb: cb
           ) == %LiveQuery.Protocol.CallbackRegistered{
             query_key: ctx[:query_key],
             client_pid: self(),
             cb_key: []
           }
  end

  test "a registered callback runs", ctx do
    LiveQuery.link(ctx[:name],
      query_key: ctx[:query_key],
      query_def: fn _ctx -> :success end,
      query_config: %{},
      client_pid: self()
    )

    LiveQuery.register_callback(ctx[:name],
      query_key: ctx[:query_key],
      client_pid: self(),
      cb_key: [],
      cb: fn event = %LiveQuery.Protocol.DataChanged{} ->
        send(event.client_pid, :the_callback_ran)
      end
    )

    LiveQuery.read(ctx[:name], query_key: ctx[:query_key])

    assert_received :the_callback_ran
  end

  test "a unregistered callback does not run", ctx do
    LiveQuery.link(ctx[:name],
      query_key: ctx[:query_key],
      query_def: fn _ctx -> :success end,
      query_config: %{},
      client_pid: self()
    )

    LiveQuery.register_callback(ctx[:name],
      query_key: ctx[:query_key],
      client_pid: self(),
      cb_key: [],
      cb: fn event = %LiveQuery.Protocol.DataChanged{} ->
        send(event.client_pid, :the_callback_ran)
      end
    )

    LiveQuery.unregister_callback(ctx[:name],
      query_key: ctx[:query_key],
      client_pid: self(),
      cb_key: []
    )

    LiveQuery.read(ctx[:name], query_key: ctx[:query_key])

    refute_received :the_callback_ran
  end

  test "unregistering all callbacks works", ctx do
    LiveQuery.link(ctx[:name],
      query_key: ctx[:query_key],
      query_def: fn _ctx -> :success end,
      query_config: %{},
      client_pid: self()
    )

    LiveQuery.register_callback(ctx[:name],
      query_key: ctx[:query_key],
      client_pid: self(),
      cb_key: [],
      cb: fn event = %LiveQuery.Protocol.DataChanged{} ->
        send(event.client_pid, :the_callback_ran)
      end
    )

    LiveQuery.unregister_all_callbacks(ctx[:name],
      query_key: ctx[:query_key],
      client_pid: self()
    )

    LiveQuery.read(ctx[:name], query_key: ctx[:query_key])

    refute_received :the_callback_ran
  end

  test "reading an unlinked but running query works", ctx do
    task_pid = start_link_supervised!({Task, fn -> Process.sleep(:infinity) end})

    LiveQuery.link(ctx[:name],
      query_key: ctx[:query_key],
      query_def: fn _ctx -> :success end,
      query_config: %{},
      client_pid: task_pid
    )

    assert LiveQuery.read(ctx[:name], query_key: ctx[:query_key]) ==
             %LiveQuery.Protocol.Data{query_key: ctx[:query_key], value: :success}

    LiveQuery.unlink(ctx[:name],
      query_key: ctx[:query_key],
      client_pid: task_pid
    )

    assert LiveQuery.read(ctx[:name], query_key: ctx[:query_key]) ==
             %LiveQuery.Protocol.NoQuery{query_key: ctx[:query_key]}
  end

  test "dependent queries work", ctx do
    LiveQuery.link(ctx[:name],
      query_key: {1, ctx[:query_key]},
      query_def: fn _ctx -> :success end,
      query_config: %{},
      client_pid: self()
    )

    LiveQuery.link(ctx[:name],
      query_key: {2, ctx[:query_key]},
      query_def: fn _ctx ->
        case LiveQuery.read(ctx[:name], query_key: {1, ctx[:query_key]}) do
          %LiveQuery.Protocol.Data{value: value} -> value
          _ -> :failure
        end
      end,
      query_config: %{},
      client_pid: self()
    )

    assert LiveQuery.read(ctx[:name], query_key: {2, ctx[:query_key]}) ==
             %LiveQuery.Protocol.Data{query_key: {2, ctx[:query_key]}, value: :success}
  end
end
