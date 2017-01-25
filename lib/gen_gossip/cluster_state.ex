defmodule GenGossip.ClusterState do
  @moduledoc false

  @opaque t :: %__MODULE__{
      node: term,
      metadata: metadata,
      cluster_name: term,
      members: [member]
  }

  @type member :: {node, member_status, metadata}

  @type member_status ::
    :joining | :valid | :invalid |
    :leaving | :exiting | :down

  @type metadata :: map

  defstruct [:node, :metadata, :cluster_name, :members]

  @spec new(term) :: t
  def new(cluster_name) do
    struct(__MODULE__, [
      node:         node(),
      metadata:     %{},
      cluster_name: cluster_name,
      members:      []
    ])
  end
end
