ExUnit.start()

defmodule Utils do
  @module (quote do
    defmodule TestGossip do
      use GenGossip
    end
  end)

  def load_test_gossip() do
    Code.eval_quoted(@module)
    Node.list()
    |> Enum.each(&:rpc.block_call(&1, Code, :eval_quoted, [@module]))
  end
end
