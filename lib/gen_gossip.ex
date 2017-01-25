defmodule GenGossip do
  @moduledoc """
  Documentation for GenGossip.
  """

  @callback init(args :: term) :: {:ok, state} | {:stop, reason :: term}

  @callback handle_gossip(msg :: term, state) :: {:ok, state} | {:stop, reason :: term}

  @type state :: term

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour GenGossip

      @doc false
      def init(arg) do
        {:ok, arg}
      end

      @doc false
      def handle_gossip(msg, state) do
        proc =
          case Process.info(self(), :registered_name) do
            {_, []}   -> self()
            {_, name} -> name
          end

        # We do this to trick Dialyzer to not complain about non-local returns.
        case :erlang.phash2(1, 1) do
          0 -> raise "attempted to call GenGossip #{inspect proc} but no handle_gossip/3 clause was provided"
          1 -> {:stop, {:bad_gossip, msg}, state}
        end
      end

      defoverridable [init: 1, handle_gossip: 2]
    end
  end

  # Cluster management api

  @spec start_link(atom, term, Keyword.t) :: GenServer.on_start
  def start_link(mod, args, opts \\ []) do
    GenServer.start_link(GenGossip.Server, [mod, args, opts], [name: mod])
  end

  @spec stop() :: :ok
  def stop do
    GenServer.cast(__MODULE__, :stop)
  end

  def join(node) when node() === node do
    {:error, :self_join}
  end
  def join(node) do
    case Node.ping(node) do
      :pang ->
        {:error, :not_reachable}
      :pong ->
        :ok # continue join
    end
  end

  def rejoin(node, cluster_state) do
    GenServer.cast({__MODULE__, node}, {:rejoin, cluster_state})
  end

  # Gossip api

  def distribute_gossip(gossip) do
    GenServer.cast({__MODULE__, node()}, {:distribute, gossip})
  end

  def send_gossip(to_node, gossip), do: send_gossip(node(), to_node, gossip)

  def send_gossip(node, node, _gossip), do: :ok
  def send_gossip(from_node, to_node, gossip) do
    GenServer.cast({__MODULE__, from_node}, {:send, to_node, gossip})
  end
end
