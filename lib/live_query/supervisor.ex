defmodule LiveQuery.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    children = [{PartitionSupervisor, child_spec: LiveQuery.Proxy.Server, name: opts[:name]}]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
