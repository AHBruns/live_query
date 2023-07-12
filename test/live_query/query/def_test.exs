defmodule LiveQuery.Query.DefTest do
  use ExUnit.Case, async: true

  setup ctx do
    name = ctx[:module]
    start_link_supervised!({LiveQuery, name: name})
    query_key = [:test]
    proxy_server = {:via, PartitionSupervisor, {name, query_key}}
    {:ok, name: name, query_key: query_key, proxy_server: proxy_server}
  end

  test "module based query defs work", ctx do
    defmodule TestQuery do
      use LiveQuery.Query.Def

      @impl true
      def init(_ctx) do
        :success
      end
    end

    LiveQuery.link(ctx[:name],
      query_key: ctx[:query_key],
      query_def: TestQuery,
      query_config: %{},
      client_pid: self()
    )

    assert LiveQuery.read(ctx[:name], query_key: ctx[:query_key]) ==
             %LiveQuery.Protocol.Data{query_key: ctx[:query_key], value: :success}
  end
end
