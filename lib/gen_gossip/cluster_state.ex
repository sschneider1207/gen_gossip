defmodule GenGossip.ClusterState do
  @moduledoc false
  alias GenGossip.VectorClock

  @opaque t :: %__MODULE__{
      owner: term,
      metadata: metadata,
      mod: atom,
      members: [Member.t],
      vector_clock: VectorClock.t
  }
  @type metadata :: Keyword.t

  defmodule Member do
    @moduledoc false
    @opaque t :: %__MODULE__{
        node: term,
        metadata: ClusterState.metadata,
        status: member_status,
        vector_clock: VectorClock.t
    }
    @type member_status ::
      :joining | :valid | :invalid |
      :leaving | :exiting | :down

    defstruct [:node, :status, :vector_clock, :metadata]
  end

  defstruct [:owner, :metadata, :mod, :members, :vector_clock]

  @spec new(term) :: t
  def new(mod) do
    struct(__MODULE__, [
      owner:         node(),
      metadata:     [],
      mod: mod,
      members:      [],
      vector_clock: VectorClock.fresh()
    ])
  end

  @spec get(atom) :: {:ok, t} | {:error, reason}
  def get(mod) do
    try do
      state = :ets.lookup_element(mod, :cluster_state, 2)
      {:ok, state}
    rescue
      _ ->
        GenServer.call(mod, :get_cluster_state)
    end
  end

  @spec get(node, atom) :: {:ok, t} | {:error, reason} | {:badrpc, reason}
  def get(node, mod) do
    :rpc.block_call(node, __MODULE__, :get_cluster_state, [mod])
  end

  def add_member() do

  end

  def set_owner(cluster_state, node) do
    struct(cluster_state, [owner: node])
  end
end
