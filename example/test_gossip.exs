defmodule TestGossip do
  use GenGossip
end

{:ok, pid} = GenGossip.start_link(TestGossip, [])
:observer.start
