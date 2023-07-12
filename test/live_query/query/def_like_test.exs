defmodule LiveQuery.Query.DefLikeTest do
  use ExUnit.Case, async: true

  setup ctx do
    name = ctx[:module]
    start_link_supervised!({LiveQuery, name: name})
    query_key = [:test]
    proxy_server = {:via, PartitionSupervisor, {name, query_key}}
    {:ok, name: name, query_key: query_key, proxy_server: proxy_server}
  end

  test "map based query defs work", ctx do
    LiveQuery.link(ctx[:name],
      query_key: ctx[:query_key],
      query_def: %{init: fn _ctx -> :success end},
      query_config: %{},
      client_pid: self()
    )

    assert LiveQuery.read(ctx[:name], query_key: ctx[:query_key]) ==
             %LiveQuery.Protocol.Data{query_key: ctx[:query_key], value: :success}
  end

  test "keyword based query defs work", ctx do
    LiveQuery.link(ctx[:name],
      query_key: ctx[:query_key],
      query_def: [init: fn _ctx -> :success end],
      query_config: %{},
      client_pid: self()
    )

    assert LiveQuery.read(ctx[:name], query_key: ctx[:query_key]) ==
             %LiveQuery.Protocol.Data{query_key: ctx[:query_key], value: :success}
  end

  test "def struct based query defs work", ctx do
    LiveQuery.link(ctx[:name],
      query_key: ctx[:query_key],
      query_def: LiveQuery.Query.Def.new(%{init: fn _ctx -> :success end}),
      query_config: %{},
      client_pid: self()
    )

    assert LiveQuery.read(ctx[:name], query_key: ctx[:query_key]) ==
             %LiveQuery.Protocol.Data{query_key: ctx[:query_key], value: :success}
  end
end
