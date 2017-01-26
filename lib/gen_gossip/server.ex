defmodule GenGossip.Server do
  @moduledoc false
  use GenServer
  alias GenGossip.ClusterState

  @default_limit {45, 10_000}  # at most 45 gossip messages every 10 seconds

  defstruct [:mod, :mod_state, :tokens, :max_tokens, :interval, :cluster_state]

  def rejoin(node, mod, state) do
    GenServer.cast({mod, node}, {:rejoin, state})
  end

  def distribute_gossip(mod) do
    GenServer.cast({mod, node()}, {:distribute})
  end

  def send_gossip(to_node, mod), do: send_gossip(node(), to_node, mod)

  def send_gossip(node, node, _, _), do: :ok
  def send_gossip(from_node, to_node, mod) do
    GenServer.cast({mod, from_node}, {:send, to_node})
  end

  @doc false
  def init([mod, args, opts]) do
    {tokens, interval} = Keyword.get(opts, :gossip_limit, @default_limit)
    cluster_state = ClusterState.new(mod)
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

  @doc false
  def handle_call({:set_my_cluster_state, cluster_state}, _from, state) do
    case ClusterState.Manager.set(state.mod, cluster_state) do
      :ok ->
        {:reply, :ok, %{state| cluster_state: cluster_state}}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_cast({:send, _to_node}, %{tokens: 0} = state) do
    {:noreply, state}
  end
  def handle_cast({:send, to_node}, state) do
    case state.mod.reconcile(to_node, state.mod_state) do
      {:ok, dump, mod_state} ->
        GenServer.cast({state.mod, to_node}, {:reconcile, state.cluster_state, dump})
      {:stop, reason} ->
        {:stop, reason}
    end
    {:noreply, %{state| tokens: state.tokens - 1}}
  end
  def handle_cast({:reconcile, cluster_state, dump}, state) do
    case state.mod.handle_gossip({:reconcile, dump}, state.mod_state) do
      {:ok, mod_state} ->
        # compare cluster_states
        {:noreply, state}
      {:stop, reason} ->
        {:stop, reason}
    end
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
