defmodule Boltx.RoutingTest do
  @moduledoc """

  """
  use Boltx.BoltKitCase, async: false

  alias Boltx.Response
  @moduletag :legacy

  @moduletag :boltkit

  @tag boltkit: %{
         url: "neo4j://127.0.0.1:9001",
         scripts: [
           {"test/scripts/non_router.script", 9001}
         ]
       }
  test "non_router.script", %{prefix: prefix} do
    assert %{error: error} = Boltx.routing_table(prefix)
    assert error =~ ~r/not a router/i
  end

  @tag boltkit: %{
         url: "neo4j://127.0.0.1:9001",
         scripts: [
           {"test/scripts/get_routing_table.script", 9001}
         ]
       }
  test "get_routing_table.script", %{prefix: prefix} do
    assert %{
             read: %{"127.0.0.1:9002" => 0},
             route: %{"127.0.0.1:9001" => 0, "127.0.0.1:9002" => 0},
             write: %{"127.0.0.1:9001" => 0}
           } = Boltx.routing_table(prefix)

    assert %Boltx.Response{
             results: [
               %{"name" => "Alice"},
               %{"name" => "Bob"},
               %{"name" => "Eve"}
             ]
           } =
             Boltx.conn(:read, prefix: prefix)
             |> Boltx.query!("MATCH (n) RETURN n.name AS name")
  end

  @tag boltkit: %{
         url: "neo4j://127.0.0.1:9001/?name=molly&age=1",
         scripts: [
           {"test/scripts/get_routing_table_with_context.script", 9001},
           {"test/scripts/return_x.bolt", 9002}
         ]
       }
  test "get_routing_table_with_context.script", %{prefix: prefix} do
    assert %{
             read: %{"127.0.0.1:9002" => 0},
             route: %{"127.0.0.1:9001" => 0, "127.0.0.1:9002" => 0},
             write: %{"127.0.0.1:9001" => 0}
           } = Boltx.routing_table(prefix)

    Boltx.conn(:read, prefix: prefix)
    |> Boltx.query!("RETURN $x", %{x: 1})
  end

  @tag boltkit: %{
         url: "neo4j://127.0.0.1:9001",
         scripts: [
           {"test/scripts/router.script", 9001},
           {"test/scripts/create_a.script", 9006}
         ]
       }
  test "create_a.script", %{prefix: prefix} do
    assert %{write: %{"127.0.0.1:9006" => 0}} = Boltx.routing_table(prefix)

    assert %Response{results: []} =
             Boltx.conn(:write, prefix: prefix)
             |> Boltx.query!("CREATE (a $x)", %{x: %{name: "Alice"}})
  end

  @tag boltkit: %{
         url: "neo4j://127.0.0.1:9001",
         scripts: [
           {"test/scripts/router.script", 9001},
           {"test/scripts/return_1.script", 9004}
         ]
       }
  test "return_1.script", %{prefix: prefix} do
    assert %{read: %{"127.0.0.1:9004" => 0}} = Boltx.routing_table(prefix)

    assert %Response{results: [%{"x" => 1}]} =
             Boltx.conn(:read, prefix: prefix)
             |> Boltx.query!("RETURN $x", %{x: 1})
  end

  @tag boltkit: %{
         url: "neo4j://127.0.0.1:9001",
         scripts: [
           {"test/scripts/router.script", 9001},
           {"test/scripts/return_1_in_tx_twice.script", 9004},
           {"test/scripts/return_1_in_tx_twice.script", 9005}
         ]
       }
  test "return_1_in_tx_twice.script", %{prefix: prefix} do
    Boltx.conn(:read, prefix: prefix)
    |> Boltx.transaction(fn conn ->
      assert %Response{fields: ["1"]} = Boltx.query!(conn, "RETURN 1")
    end)
  end

  @tag boltkit: %{
         url: "neo4j://127.0.0.1:9001",
         scripts: [
           {"test/scripts/router.script", 9001},
           {"test/scripts/return_1_twice.script", 9004},
           {"test/scripts/return_1_twice.script", 9005}
         ]
       }
  test "return_1_twice.script", %{prefix: prefix} do
    rconn1 = Boltx.conn(:read, prefix: prefix)
    rconn2 = Boltx.conn(:read, prefix: prefix)
    assert %Response{results: [%{"x" => 1}]} = Boltx.query!(rconn1, "RETURN $x", %{x: 1})
    assert %Response{results: [%{"x" => 1}]} = Boltx.query!(rconn2, "RETURN $x", %{x: 1})
  end

  @tag boltkit: %{
         url: "neo4j://127.0.0.1:9001",
         scripts: [
           {"test/scripts/router.script", 9001},
           {"test/scripts/forbidden_on_read_only_database.script", 9006}
         ]
       }
  test "forbidden_on_read_only_database.script", %{prefix: prefix} do
    conn = Boltx.conn(:write, prefix: prefix)

    assert_raise Boltx.Exception, ~r/unable to write/i, fn ->
      Boltx.query!(conn, "CREATE (n {name:'Bob'})")
    end
  end
end
