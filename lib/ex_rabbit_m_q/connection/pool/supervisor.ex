defmodule ExRabbitMQ.Connection.Pool.Supervisor do
  @moduledoc """
  A supervisor implementing the `DynamicSupervisor` with `:one_for_one` strategy to serve as a template for spawning
  new RabbitMQ connection (module `ExRabbitMQ.Connection`) processes.
  """

  use DynamicSupervisor

  alias ExRabbitMQ.Config.Connection, as: ConnectionConfig
  alias ExRabbitMQ.Connection.Pool
  alias ExRabbitMQ.Connection.Pool.Registry, as: RegistryPool

  @doc """
  Starts a new process for supervising `ExRabbitMQ.Connection` processes.
  """
  @spec start_link(term) :: Supervisor.on_start()
  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Starts a new `ExRabbitMQ.Connection` process with the specified configuration and supervises it.
  """
  @spec start_child(atom, ConnectionConfig.t() | atom) :: Supervisor.on_start_child()
  def start_child(app \\ :exrabbitmq, connection_key) do
    {hash_key, connection_config} =
      app
      |> ConnectionConfig.get(connection_key)
      |> ConnectionConfig.to_hash_key()

    child_spec = %{
      id: hash_key,
      start: {Pool, :start, [hash_key, connection_config]}
      # restart: :transient,
      # shutdown: 5000,
      # type: :worker
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def stop_pools() do
    RegistryPool.unlink_stop()

    __MODULE__
    |> Process.whereis()
    |> DynamicSupervisor.which_children()
    |> Enum.reduce([], fn x, acc -> [elem(x, 1) | acc] end)
    |> Enum.each(fn x ->
      Process.unlink(x)
      :poolboy.stop(x)
    end)
  end
end
