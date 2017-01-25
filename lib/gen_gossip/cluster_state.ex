defmodule GenGossip.ClusterState do
  @moduledoc false
  alias GenGossip.VectorClock

  @opaque t :: %__MODULE__{
      node: term,
      metadata: metadata,
      cluster_name: term,
      members: [member],
      vector_clock: VectorClock.t
  }

  @type member :: {node, member_status, metadata}

  @type member_status ::
    :joining | :valid | :invalid |
    :leaving | :exiting | :down

  @type metadata :: map

  defstruct [:node, :metadata, :cluster_name, :members, :vector_clock]

  @spec new(term) :: t
  def new(cluster_name) do
    struct(__MODULE__, [
      node:         node(),
      metadata:     %{},
      cluster_name: cluster_name,
      members:      [],
      vector_clock: VectorClock.fresh()
    ])
  end
end
