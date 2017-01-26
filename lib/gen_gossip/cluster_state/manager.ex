defmodule GenGossip.ClusterState.Manager do
  use GenServer
  alias GenGossip.ClusterState

  def start_link(mod) do
    GenServer.start_link(__MODULE__, [mod], name: name(mod))
  end

  @spec get(atom) :: {:ok, ClusterState.t} | {:error, term}
  def get(mod) do
    try do
      state = :ets.lookup_element(mod, :cluster_state, 2)
      {:ok, state}
    rescue
      _ ->
        Module.concat(mod, Manager)
        |> GenServer.call(:get)
    end
  end

  @spec get(node, atom) :: {:ok, ClusterState.t} | {:error, term} | {:badrpc, term}
  def get(node, mod) do
    :rpc.block_call(node, __MODULE__, :get, [mod])
  end
  @spec set(atom, ClusterState.t) :: :ok | {:error, :not_found}
  def set(mod, state) do
    GenServer.call(name(mod), {:set, state})
  end

  def name(mod) do
    Module.concat(mod, Manager)
  end

  @doc false
  def init([mod]) do
    cluster_tab = :ets.new(mod, [:named_table, {:read_concurrency, true}])
    cluster_state = ClusterState.new(mod)
    true = :ets.insert(cluster_tab, {:cluster_state, cluster_state})
    {:ok, cluster_tab}
  end

  @doc false
  def handle_call(:get, _from, tab) do
    state = :ets.lookup_element(tab, :cluster_state, 2)
    {:reply, state, tab}
  end
  def handle_call({:set, new_state}, _from, tab) do
    try do
      true = :ets.update_element(tab, :cluster_state, {2, new_state})
      {:reply, :ok, tab}
    rescue
      _ ->
      {:stop, :error_updating_global_state, tab}
    end
  end
end
