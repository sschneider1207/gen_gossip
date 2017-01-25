defmodule GenGossip.Server do
  @moduledoc false
  use GenServer
  alias GenGossip.ClusterState

  @default_limit {45, 10_000}  # at most 45 gossip messages every 10 seconds

  defstruct [:mod, :mod_state, :tokens, :max_tokens, :interval, :cluster_state]

  @doc false
  def init([mod, args, opts]) do
    {tokens, interval} = Keyword.get(opts, :gossip_limit, @default_limit)
    cluster_state = init_cluster_table(mod)
    state = struct(__MODULE__, [
      mod:           mod,
      max_tokens:    tokens,
      tokens:        tokens,
      interval:      interval,
      cluster_state: cluster_state
    ])
    schedule_next_reset(state)
    case mod.init(args) do
      {:ok, mod_state} ->
        updated_state = %{state| mod_state: mod_state}
        {:ok, updated_state}
      {:stop, reason} ->
        {:stop, reason}
    end
  end

  defp init_cluster_table(mod) do
    cluster_tab = :ets.new(mod, [:named_table, {:read_concurrency, true}])
    cluster_state = ClusterState.new(mod)
    true = :ets.insert(cluster_tab, {:cluster_state, cluster_state})
    cluster_state
  end

  @doc false
  def handle_call(:get_cluster_state, _from, state) do
    {:reply, {:ok, state.cluster_state}, state}
  end

  @doc false
  def handle_info(:reset_tokens, %{max_tokens: tokens} = state) do
    schedule_next_reset(state)
    {:noreply, %{state| tokens: tokens}}
  end

  defp schedule_next_reset(%{interval: interval}) do
    Process.send_after(self(), :reset_tokens, interval)
  end
end
