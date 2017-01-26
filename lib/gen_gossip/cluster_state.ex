defmodule GenGossip.ClusterState do
  alias GenGossip.VectorClock

  @opaque t :: %__MODULE__{
      owner: term,
      metadata: metadata,
      mod: atom,
      members: [{term, Member.t}],
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
    cluster_state = struct(__MODULE__, [
      owner:        node(),
      metadata:     [],
      mod:          mod,
      members:      [],
      vector_clock: VectorClock.fresh()
    ])
  end
  
  def add_member(pnode, state, node) do
    set_member(pnode, state, node, :joining)
  end

  def remove_member(pnode, state, node) do
    set_member(pnode, state, node, :invalid)
  end

  def leave_member(pnode, state, node) do
    set_member(pnode, state, node, :leaving)
  end

  def exit_member(pnode, state, node) do
    set_member(pnode, state, node, :exiting)
  end

  def down_member(pnode, state, node) do
    set_member(pnode, state, node, :down)
  end

  defp set_member(node, state, member, status) do
    vector_clock = VectorClock.increment(state.vector_clock, node)
    updated_state = update_members(node, state, member, status)
    struct(updated_state, [vector_clock: vector_clock])
  end

  defp update_members(node, state, member, status) do
    members = :orddict.update(member,
                              &update_member(&1, status),
                              default_member(member, status),
                              state.members)
    struct(__MODULE__, [members: members])
  end

  defp default_member(name, status) do
    struct(Member, [vector_clock: VectorClock.fresh(), status: status, node: name])
  end

  defp update_member(member, status) do
    vector_clock = VectorClock.increment(member.vector_clock, member.node)
    struct(Member, [vector_clock: vector_clock, status: status])
  end

  def set_owner(state, node) do
    struct(state, [owner: node])
  end
end
