module = quote do
  defmodule TestGossip do
    use GenGossip
  end
end

Code.eval_quoted(module)

slaves = for {:ok, node} <- DistributedEnv.start(3), do: node
GenGossip.start_link(TestGossip, [])
for node <- slaves do
  :rpc.block_call(node, Code, :eval_quoted, [module])
  :rpc.block_call(node, GenGossip, :start_link, [TestGossip, []])
end
:observer.start
