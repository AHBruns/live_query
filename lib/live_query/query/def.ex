defmodule LiveQuery.Query.Def do
  @moduledoc """
  This module defines the `LiveQuery.Query.Def` behaviour and struct.
  The behaviour can be used to make a module-base query definition.
  The struct can be used as a query definition itself.
  """

  @enforce_keys [:init]
  defstruct [:init, :handle_call, :handle_cast, :handle_info]

  @type data :: any
  @type t :: %__MODULE__{
          init: (state :: %{required(:key) => any, required(:config) => map} -> data),
          handle_call:
            (msg :: any,
             from :: GenServer.from(),
             state :: %{
               required(:key) => any,
               required(:config) => map,
               optional(:data) => data
             } ->
               {:noreply, data} | {:reply, any, data})
            | nil,
          handle_cast:
            (msg :: any,
             state :: %{
               required(:key) => any,
               required(:config) => map,
               optional(:data) => data
             } ->
               data)
            | nil,
          handle_info:
            (msg :: any,
             state :: %{
               required(:key) => any,
               required(:config) => map,
               optional(:data) => data
             } ->
               data)
            | nil
        }

  @callback init(state :: %{required(:key) => any, required(:config) => map}) :: data
  @callback handle_call(
              msg :: any,
              from :: GenServer.from(),
              state :: %{required(:key) => any, required(:config) => map, optional(:data) => data}
            ) :: {:noreply, data} | {:reply, any, data}
  @callback handle_cast(
              msg :: any,
              state :: %{required(:key) => any, required(:config) => map, optional(:data) => data}
            ) :: data
  @callback handle_info(
              msg :: any,
              state :: %{required(:key) => any, required(:config) => map, optional(:data) => data}
            ) :: data

  @optional_callbacks [handle_call: 3, handle_cast: 2, handle_info: 2]

  @doc """
  Just adds the `LiveQuery.Query.Def` behaviour to your module for you.
  Modules which implement this behaviour can be used as a query definition.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour LiveQuery.Query.Def
    end
  end

  @doc """
  Creates a new `LiveQuery.Query.Def` struct which implements the `LiveQuery.Query.DefLike` protocol.
  """
  @spec new(%{
          required(:init) =>
            (state :: %{required(:key) => any, required(:config) => map} ->
               data),
          optional(:handle_call) =>
            (msg :: any,
             from :: GenServer.from(),
             state :: %{
               required(:key) => any,
               required(:config) => map,
               optional(:data) => data
             } ->
               {:noreply, data} | {:reply, any, data}),
          optional(:handle_cast) =>
            (msg :: any,
             state :: %{
               required(:key) => any,
               required(:config) => map,
               optional(:data) => data
             } ->
               data),
          optional(:handle_info) =>
            (msg :: any,
             state :: %{
               required(:key) => any,
               required(:config) => map,
               optional(:data) => data
             } ->
               data)
        }) :: t
  def new(opts) do
    %__MODULE__{
      init: opts.init,
      handle_call: opts[:handle_call],
      handle_cast: opts[:handle_cast],
      handle_info: opts[:handle_info]
    }
  end

  defimpl LiveQuery.Query.DefLike do
    def init(self, state) do
      self.init.(state)
    end

    def handle_call(self, msg, from, state) do
      self.handle_call.(msg, from, state)
    end

    def handle_cast(self, msg, state) do
      self.handle_cast.(msg, state)
    end

    def handle_info(self, msg, state) do
      self.handle_info.(msg, state)
    end
  end
end
