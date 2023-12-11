defmodule One.Test do
  # use Boltx.RoutingConnCase
  # @moduletag :routing

  # # alias Boltx.{Success, Error, Response}
  # # alias Boltx.Types.{Node, Relationship, UnboundRelationship, Path}

  # @tag :routing
  # test "temporary placeholder for focused tests during development/debugging" do
  #   assert %{"r" => 300} ==
  #            Boltx.conn(:write) |> Boltx.query!("RETURN 300 AS r") |> List.first()
  # end

  use ExUnit.Case
  alias Boltx.Response
  @moduletag :legacy

  test "a simple query" do
    conn = Boltx.conn()
    response = Boltx.query!(conn, "RETURN 300 AS r")

    assert %Response{results: [%{"r" => 300}]} = response
    assert response |> Enum.member?("r")
    assert 1 = response |> Enum.count()
    assert [%{"r" => 300}] = response |> Enum.take(1)
    assert %{"r" => 300} = response |> Response.first()
  end

  # @tag :skip
  test "multiple statements" do
    conn = Boltx.conn()

    q = """
    MATCH (n {boltx: true}) OPTIONAL MATCH (n)-[r]-() DELETE n,r;
    CREATE (BoltSip:BoltSip {title:'Elixir sipping from Neo4j, using Bolt', released:2016, license:'MIT', boltx: true});
    MATCH (b:boltx{boltx: true}) RETURN b
    """

    l = Boltx.query!(conn, q)
    assert is_list(l)

    assert 3 ==
             Enum.filter(l, fn
               %Response{} -> true
               _ -> false
             end)
             |> Enum.count()
  end
end
