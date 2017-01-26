module = quote do
  defmodule KvpGossip do
    use GenGossip

    def set(key, value) do

    end

    def init(initial_entries) do
      tab = :ets.new(:bucket, [:named_table, {:read_concurrency, true}])
      true = :ets.insert(tab, initial_entries)
      {:ok, tab}
    end
  end
end

Code.eval_quoted(module)

slaves = for {:ok, node} <- DistributedEnv.start(3), do: node
GenGossip.start_link(KvpGossip, [])
GenGossip.ClusterState.Manager.start_link(KvpGossip)
for node <- slaves do
  :rpc.block_call(node, Code, :eval_quoted, [module])
  :rpc.block_call(node, GenGossip, :start_link, [KvpGossip, []])
  :rpc.block_call(node, GenGossip.ClusterState.Manager, :start_link, [KvpGossip])
end
:observer.start
