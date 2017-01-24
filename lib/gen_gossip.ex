defmodule GenGossip do
  @moduledoc """
  Documentation for GenGossip.
  """

  @callback init(args :: term) :: {:ok, state} | {:stop, reason :: term}

  @callback handle_gossip(msg, state) :: {:ok, state} | {:stop, reason :: term}

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

  @spec start_link(atom, term, Keyword.t) :: GenServer.on_start
  def start_link(mod, args, opts \\ []) do
    GenServer.start_link(GenGossip.Server, [mod, args, opts], [name: mod])
  end
end
