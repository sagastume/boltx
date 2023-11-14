defmodule Boltx.RoutingConnCase do
  @moduletag :routing

  use ExUnit.CaseTemplate

  alias Boltx

  @routing_connection_config [
    url: "bolt+routing://localhost:9001",
    basic_auth: [username: "neo4j", password: "test"],
    pool_size: 10,
    max_overflow: 2,
    queue_interval: 500,
    queue_target: 1500,
    tag: @moduletag
  ]

  setup_all do
    {:ok, _pid} = Boltx.start_link(@routing_connection_config)
    conn = Boltx.conn(:write)

    on_exit(fn ->
      with conn when not is_nil(conn) <- Boltx.conn(:write) do
        Boltx.Test.Support.Database.clear(conn)
      else
        e -> {:error, e}
      end
    end)

    {:ok, write_conn: conn}
  end
end
