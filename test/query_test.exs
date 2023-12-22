defmodule Query.Test do
  use Boltx.ConnCase, async: true

  alias Query.Test
  alias Boltx.Test.Support.Database
  alias Boltx.Response
  @moduletag :legacy

  defmodule TestUser do
    defstruct name: "", boltx: true
  end

  defp rebuild_fixtures(conn) do
    Database.clear(conn)
    Boltx.Fixture.create_graph(conn, :boltx)
  end

  setup(%{conn: conn} = context) do
    rebuild_fixtures(conn)
    {:ok, context}
  end

  @tag :apoc
  test "Passing a timeout option to the query should prevent a timeout", context do
    conn = context[:conn]

    cyp_wait = """
      CALL apoc.util.sleep(20000) RETURN 1 as test
    """

    {:ok, %Response{} = _row} = Boltx.query(conn, cyp_wait, %{}, timeout: 21_000)
  end

  @tag :apoc
  test "After a timeout, subsequent queries should work", context do
    conn = context[:conn]

    cyp_wait = """
      CALL apoc.util.sleep(10000) RETURN 1 as test
    """

    {:error, _} = Boltx.query(conn, cyp_wait, %{}, timeout: 5_000)

    cyp = """
      MATCH (n:Person {boltx: true})
      RETURN n.name AS Name
      ORDER BY Name DESC
      LIMIT 5
    """

    {:ok, %Response{} = row} = Boltx.query(conn, cyp)

    assert Response.first(row)["Name"] == "Patrick Rothfuss",
           "missing 'The Name of the Wind' database, or data incomplete"
  end

  test "if Patrick Rothfuss wrote The Name of the Wind", c do
    cypher = """
      MATCH (p:Person)-[r:WROTE]->(b:Book {title: 'The Name of the Wind'})
      RETURN p
    """

    %Response{} = rows = Boltx.query!(c.conn, cypher)
    assert Response.first(rows)["p"].properties["name"] == "Patrick Rothfuss"
  end

  test "executing a raw Cypher query with alias, and no parameters", c do
    cypher = """
      MATCH (p:Person {boltx: true})
      RETURN p, p.name AS name, toUpper(p.name) as NAME,
             coalesce(p.nickname,"n/a") AS nickname,
             { name: p.name, label:head(labels(p))} AS person
      ORDER BY name DESC
    """

    {:ok, %Response{} = r} = Boltx.query(c.conn, cypher)

    assert Enum.count(r) == 3,
           "you're missing some characters from the 'The Name of the Wind' db"

    if row = Response.first(r) do
      assert row["p"].properties["name"] == "Patrick Rothfuss"
      assert is_map(row["p"]), "was expecting a map `p`"
      assert row["person"]["label"] == "Person"
      assert row["NAME"] == "PATRICK ROTHFUSS"
      assert row["nickname"] == "n/a"
      assert row["p"].properties["boltx"] == true
    else
      IO.puts("Did you initialize the 'The Name of the Wind' database?")
    end
  end

  test "it returns only known role names", context do
    conn = context[:conn]

    cypher = """
      MATCH (p)-[r:ACTED_IN]->() where p.boltx RETURN r.roles as roles
      LIMIT 25
    """

    %Response{results: rows} = Boltx.query!(conn, cypher)
    roles = ["killer", "sword fighter", "magician", "musician", "many talents"]
    my_roles = Enum.map(rows, & &1["roles"]) |> List.flatten()
    assert my_roles -- roles == [], "found more roles in the db than expected"
  end

  test "path from: MERGE p=({name:'Alice'})-[:KNOWS]-> ...", context do
    conn = context[:conn]

    cypher = """
    MERGE p = ({name:'Alice', boltx: true})-[:KNOWS]->({name:'Bob', boltx: true})
    RETURN p
    """

    path =
      Boltx.query!(conn, cypher)
      |> Response.first()
      |> Map.get("p")

    assert {2, 1} == {length(path.nodes), length(path.relationships)}
  end

  test "return a single number from a statement with params", context do
    conn = context[:conn]
    row = Boltx.query!(conn, "RETURN $n AS num", %{n: 10}) |> Response.first()
    assert row["num"] == 10
  end

  test "run simple statement with complex params", context do
    conn = context[:conn]

    row =
      Boltx.query!(conn, "RETURN $x AS n", %{x: %{abc: ["d", "e", "f"]}})
      |> Response.first()

    assert row["n"]["abc"] == ["d", "e", "f"]
  end

  test "return an array of numbers", context do
    conn = context[:conn]
    row = Boltx.query!(conn, "RETURN [10,11,21] AS arr") |> Response.first()
    assert row["arr"] == [10, 11, 21]
  end

  test "return a string", context do
    conn = context[:conn]
    row = Boltx.query!(conn, "RETURN 'Hello' AS salute") |> Response.first()
    assert row["salute"] == "Hello"
  end

  test "UNWIND range(1, 10) AS n RETURN n", context do
    conn = context[:conn]

    assert %Response{results: rows} = Boltx.query!(conn, "UNWIND range(1, 10) AS n RETURN n")

    assert {1, 10} == rows |> Enum.map(& &1["n"]) |> Enum.min_max()
  end

  test "MERGE (k:Person {name:'Kote'}) RETURN k", context do
    conn = context[:conn]

    k =
      Boltx.query!(conn, "MERGE (k:Person {name:'Kote', boltx: true}) RETURN k LIMIT 1")
      |> Response.first()
      |> Map.get("k")

    assert k.labels == ["Person"]
    assert k.properties["name"] == "Kote"
  end

  test "query/2 and query!/2", context do
    conn = context[:conn]

    assert r = Boltx.query!(conn, "RETURN [10,11,21] AS arr")
    assert [10, 11, 21] = Response.first(r)["arr"]

    assert {:ok, %Response{} = r} = Boltx.query(conn, "RETURN [10,11,21] AS arr")
    assert [10, 11, 21] = Response.first(r)["arr"]
  end

  test "create a Bob node and check it was deleted afterwards", context do
    conn = context[:conn]

    assert %Response{stats: stats} = Boltx.query!(conn, "CREATE (a:Person {name:'Bob'})")
    assert stats == %{"labels-added" => 1, "nodes-created" => 1, "properties-set" => 1}

    assert ["Bob"] ==
             Boltx.query!(conn, "MATCH (a:Person {name: 'Bob'}) RETURN a.name AS name")
             |> Enum.map(& &1["name"])

    assert %Response{stats: stats} =
             Boltx.query!(conn, "MATCH (a:Person {name:'Bob'}) DELETE a")

    assert stats["nodes-deleted"] == 1
  end

  test "Cypher version 3", context do
    conn = context[:conn]

    assert %Response{plan: plan} = Boltx.query!(conn, "EXPLAIN RETURN 1")
    refute plan == nil
    assert Regex.match?(~r/CYPHER [3|4]/iu, plan["args"]["version"])
  end

  test "EXPLAIN MATCH (n), (m) RETURN n, m", context do
    conn = context[:conn]

    assert %Response{notifications: notifications, plan: plan} =
             Boltx.query!(conn, "EXPLAIN MATCH (n), (m) RETURN n, m")

    refute notifications == nil
    refute plan == nil

    if Regex.match?(~r/CYPHER 3/iu, plan["args"]["version"]) do
      assert "CartesianProduct" ==
               plan["children"]
               |> List.first()
               |> Map.get("operatorType")
    else
      assert(
        "CartesianProduct@neo4j" ==
          plan["children"]
          |> List.first()
          |> Map.get("operatorType")
      )
    end
  end

  test "can execute a query after a failure", context do
    conn = context[:conn]
    assert {:error, _} = Boltx.query(conn, "INVALID CYPHER")
    assert {:ok, %Response{results: [%{"n" => 22}]}} = Boltx.query(conn, "RETURN 22 as n")
  end

  test "negative numbers are returned as negative numbers", context do
    conn = context[:conn]
    assert {:ok, %Response{results: [%{"n" => -1}]}} = Boltx.query(conn, "RETURN -1 as n")
  end

  test "return a simple node", context do
    conn = context[:conn]

    assert %Response{
             results: [
               %{
                 "p" => %Boltx.Types.Node{
                   id: _,
                   labels: ["Person"],
                   properties: %{"boltx" => true, "name" => "Patrick Rothfuss"}
                 }
               }
             ]
           } = Boltx.query!(conn, "MATCH (p:Person {name: 'Patrick Rothfuss'}) RETURN p")
  end

  test "Simple relationship", context do
    conn = context[:conn]

    cypher = """
      MATCH (p:Person)-[r:WROTE]->(b:Book {title: 'The Name of the Wind'})
      RETURN r
    """

    assert %Response{
             results: [
               %{
                 "r" => %Boltx.Types.Relationship{
                   end: _,
                   id: _,
                   properties: %{},
                   start: _,
                   type: "WROTE"
                 }
               }
             ]
           } = Boltx.query!(conn, cypher)
  end

  test "simple path", context do
    conn = context[:conn]

    cypher = """
    MERGE p = ({name:'Alice', boltx: true})-[:KNOWS]->({name:'Bob', boltx: true})
    RETURN p
    """

    assert %Response{
             results: [
               %{
                 "p" => %Boltx.Types.Path{
                   nodes: [
                     %Boltx.Types.Node{
                       id: _,
                       labels: [],
                       properties: %{"boltx" => true, "name" => "Alice"}
                     },
                     %Boltx.Types.Node{
                       id: _,
                       labels: [],
                       properties: %{"boltx" => true, "name" => "Bob"}
                     }
                   ],
                   relationships: [
                     %Boltx.Types.UnboundRelationship{
                       end: nil,
                       id: _,
                       properties: %{},
                       start: nil,
                       type: "KNOWS"
                     }
                   ],
                   sequence: [1, 1]
                 }
               }
             ]
           } = Boltx.query!(conn, cypher)
  end

  test "transaction (commit)", context do
    conn = context[:conn]

    Boltx.transaction(conn, fn conn ->
      book =
        Boltx.query!(conn, "CREATE (b:Book {title: \"The Game Of Trolls\"}) return b")
        |> Response.first()

      assert %{"b" => g_o_t} = book
      assert g_o_t.properties["title"] == "The Game Of Trolls"
    end)

    %Response{} =
      books = Boltx.query!(conn, "MATCH (b:Book {title: \"The Game Of Trolls\"}) return b")

    assert 1 == Enum.count(books)

    # Clean data

    rem_books = "MATCH (b:Book {title: \"The Game Of Trolls\"}) DELETE b"
    Boltx.query!(conn, rem_books)
  end

  test "transaction (rollback)", context do
    conn = context[:conn]

    Boltx.transaction(conn, fn conn ->
      book =
        Boltx.query!(conn, "CREATE (b:Book {title: \"The Game Of Trolls\"}) return b")
        |> Response.first()

      assert %{"b" => g_o_t} = book
      assert g_o_t.properties["title"] == "The Game Of Trolls"
      Boltx.rollback(conn, :changed_my_mind)
    end)

    assert %Response{} =
             r = Boltx.query!(conn, "MATCH (b:Book {title: \"The Game Of Trolls\"}) return b")

    assert Enum.count(r) == 0
  end
end
