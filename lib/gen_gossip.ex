defmodule GenGossip do
  @moduledoc """
  Documentation for GenGossip.
  """
  alias GenGossip.ClusterState

  @callback init(args :: term) ::
    {:ok, state} |
    {:stop, reason :: term}

  @callback reconcile(to :: node, state) ::
    {:ok, term, state} |
    {:stop, reason :: term}

  @callback handle_gossip(msg :: term, state) ::
    {:ok, state} |
    {:stop, reason :: term}

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
      def reconcile(_to, state) do
        {:ok, state, state}
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

      defoverridable [init: 1, reconcile: 2, handle_gossip: 2]
    end
  end

  # Cluster management api

  @spec start_link(atom, term, Keyword.t) :: GenServer.on_start
  def start_link(mod, args, opts \\ []) do
    GenServer.start_link(GenGossip.Server, [mod, args, opts], [name: mod])
  end

  @spec stop(atom) :: :ok
  def stop(mod) do
    GenServer.cast(mod, :stop)
  end

  def join(node, _) when node() === node do
    {:error, :self_join}
  end
  def join(node, mod) do
    join(node, mod, false)
  end

  def join(node, _, _) when node() === node do
    {:error, :self_join}
  end
  def join(node, mod, rejoin) do
    with {:started, _}       <- :init.get_status(),
         :pong               <- Node.ping(node),
         {:ok, their_state}  <- ClusterState.Manager.get(node, mod)
    do
      do_join(node, mod, their_state, rejoin)
    else
      :pang ->
        {:error, :not_reachable}
      {status, _} when status in [:starting, :stopping] ->
        {:error, :not_started}
      {:error, err} ->
        {:error, err}
      {:badrpc, reason} ->
        {:badrpc, reason}
    end
  end

  defp do_join(node, mod, state, rejoin) do
    updated_state =
      ClusterState.add_member(node(), state, node())
      |> ClusterState.set_owner(node())
    case ClusterState.Manager.set(mod, updated_state) do
      :ok ->
        GenGossip.Server.send_gossip(node, node(), mod)
      {:error, reason} ->
        {:error, reason}
    end
  end
end
