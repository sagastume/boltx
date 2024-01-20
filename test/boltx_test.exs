defmodule BoltxTest do
  use ExUnit.Case, async: true

  alias Boltx.Response
  alias Boltx.Types.{Duration, Point}

  @opts Boltx.TestHelper.opts()

  defmodule TestUser do
    defstruct name: "", boltx: true
  end

  describe "connect" do
    @tag :core
    test "connect using default protocol" do
      opts = [pool_size: 1] ++ @opts
      {:ok, conn} = Boltx.start_link(opts)
      Boltx.query!(conn, "RETURN 1024 AS a")
    end
  end

  describe "query" do
    setup [:connect, :truncate, :rebuild_fixtures]

    @tag :core
    test "a simple query", c do
      response = Boltx.query!(c.conn, "RETURN 300 AS r")

      assert %Response{results: [%{"r" => 300}]} = response
      assert response |> Enum.member?("r")
      assert 1 = response |> Enum.count()
      assert [%{"r" => 300}] = response |> Enum.take(1)
      assert %{"r" => 300} = response |> Response.first()
    end

    @tag :core
    test "a simple query to get persons", c do
      self = self()

      query = """
        MATCH (n:Person {boltx: true})
        RETURN n.name AS Name
        ORDER BY Name DESC
        LIMIT 5
      """

      {:ok, %Response{} = response} = Boltx.query(c.conn, query, %{}, log: &send(self, &1))
      assert_received %DBConnection.LogEntry{} = entry
      assert %Boltx.Query{} = entry.query

      assert Response.first(response)["Name"] == "Patrick Rothfuss",
             "missing Person database, or data incomplete"
    end

    @tag :core
    test "a simple queries to get persons with many queries", c do
      self = self()

      query = """
        MATCH (n:Person {name:'Patrick Rothfuss'})
        RETURN n.name AS Name
        ORDER BY Name DESC
        LIMIT 1;
        MATCH (n:Person {name:'Kote'})
        RETURN n.name AS Name
        ORDER BY Name DESC
        LIMIT 1;
      """

      {:ok, responses} = Boltx.query_many(c.conn, query, %{}, log: &send(self, &1))
      assert is_list(responses)
      assert Enum.any?(responses, &(is_map(&1) and &1.__struct__ == Response))

      assert Response.first(hd(responses))["Name"] == "Patrick Rothfuss",
             "missing 'The Name Patrick' database, or data incomplete"

      assert Response.first(Enum.at(responses, 1))["Name"] == "Kote",
             "missing 'The Name Kote' database, or data incomplete"
    end

    @tag :bolt_2_x
    @tag :bolt_3_x
    @tag :bolt_4_x
    @tag :bolt_5_x
    test "a query to get a Node with temporal functions", c do
      uuid = "6152f30e-076a-4479-b575-764bf6ab5e38"
      Boltx.query!(c.conn, "CREATE (user:User{uuid: $uuid, name: 'John', created_at: DATETIME()})", %{uuid: uuid})
      response = Boltx.query!(c.conn, "MATCH (user:User {uuid: $uuid })RETURN user", %{uuid: uuid})

      assert %Boltx.Response{
        results: [
          %{
            "user" => %Boltx.Types.Node{
              id: _,
              properties: %{
                "created_at" => _,
                "name" => "John",
                "uuid" => "6152f30e-076a-4479-b575-764bf6ab5e38"
              }
            }
          }
        ]
      } = response
    end

    @tag :core
    test "A procedure call failure should send reset and not lock the db" do
      opts = [pool_size: 1] ++ @opts
      {:ok, conn} = Boltx.start_link(opts)

      cypher_fail = "INVALID CYPHER"
      {:error, %Boltx.Error{code: :syntax_error}} = Boltx.query(conn, cypher_fail)

      cypher_query = """
        MATCH (n:Person {boltx: true})
        RETURN n.name AS Name
        ORDER BY Name DESC
        LIMIT 5
      """

      assert {:ok, %Response{} = response} = Boltx.query(conn, cypher_query, %{})

      assert Response.first(response)["Name"] == "Patrick Rothfuss",
             "missing Person database, or data incomplete"
    end

    @tag :core
    test "executing a Cypher query, with parameters", c do
      cypher = """
        MATCH (n:Person {boltx: true})
        WHERE n.name = $name
        RETURN n.name AS name
      """

      parameters = %{name: "Kote"}

      {:ok, %Response{} = response} = Boltx.query(c.conn, cypher, parameters)
      assert Response.first(response)["name"] == "Kote"
    end

    @tag :core
    test "executing a Cypher query, with struct parameters", c do
      cypher = """
        CREATE(n:User $props)
      """

      assert {:ok, %Response{stats: stats, type: type}} =
               Boltx.query(c.conn, cypher, %{
                 props: %BoltxTest.TestUser{name: "Strut", boltx: true}
               })

      assert stats["labels-added"] == 1
      assert stats["nodes-created"] == 1
      assert stats["properties-set"] == 2
      assert type == "w"
    end

    @tag :core
    test "executing a Cpyher query, with map parameters", c do
      cypher = """
        CREATE(n:User $props)
      """

      assert {:ok, %Response{stats: stats, type: type}} =
               Boltx.query(c.conn, cypher, %{props: %{name: "Mep", boltx: true}})

      assert stats["labels-added"] == 1
      assert stats["nodes-created"] == 1
      assert stats["properties-set"] == 2
      assert type == "w"
    end

    @tag :core
    test "it returns only known role names", c do
      cypher = """
        MATCH (p)-[r:ACTED_IN]->() where p.boltx RETURN r.roles as roles
        LIMIT 25
      """

      %Response{results: rows} = Boltx.query!(c.conn, cypher)
      roles = ["killer", "sword fighter", "magician", "musician", "many talents"]
      my_roles = Enum.map(rows, & &1["roles"]) |> List.flatten()
      assert my_roles -- roles == [], "found more roles in the db than expected"
    end

    @tag :core
    test "if Patrick Rothfuss wrote The Name of the Wind", c do
      cypher = """
        MATCH (p:Person)-[r:WROTE]->(b:Book {title: 'The Name of the Wind'})
        RETURN p
      """

      %Response{} = rows = Boltx.query!(c.conn, cypher)
      assert Response.first(rows)["p"].properties["name"] == "Patrick Rothfuss"
    end

    @tag :core
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

    @tag :core
    test "path from: MERGE p=({name:'Alice'})-[:KNOWS]-> ...", c do
      cypher = """
      MERGE p = ({name:'Alice', boltx: true})-[:KNOWS]->({name:'Bob', boltx: true})
      RETURN p
      """

      path =
        Boltx.query!(c.conn, cypher)
        |> Response.first()
        |> Map.get("p")

      assert {2, 1} == {length(path.nodes), length(path.relationships)}
    end

    @tag :core
    test "return a single number from a statement with params", c do
      row = Boltx.query!(c.conn, "RETURN $n AS num", %{n: 10}) |> Response.first()
      assert row["num"] == 10
    end

    @tag :core
    test "run simple statement with complex params", c do
      row =
        Boltx.query!(c.conn, "RETURN $x AS n", %{x: %{abc: ["d", "e", "f"]}})
        |> Response.first()

      assert row["n"]["abc"] == ["d", "e", "f"]
    end

    @tag :core
    test "return an array of numbers", c do
      row = Boltx.query!(c.conn, "RETURN [10,11,21] AS arr") |> Response.first()
      assert row["arr"] == [10, 11, 21]
    end

    @tag :core
    test "return a string", c do
      row = Boltx.query!(c.conn, "RETURN 'Hello' AS salute") |> Response.first()
      assert row["salute"] == "Hello"
    end

    @tag :core
    test "UNWIND range(1, 10) AS n RETURN n", c do
      assert %Response{results: rows} = Boltx.query!(c.conn, "UNWIND range(1, 10) AS n RETURN n")
      assert {1, 10} == rows |> Enum.map(& &1["n"]) |> Enum.min_max()
    end

    @tag :core
    test "MERGE (k:Person {name:'Kote'}) RETURN k", c do
      k =
        Boltx.query!(c.conn, "MERGE (k:Person {name:'Kote', boltx: true}) RETURN k LIMIT 1")
        |> Response.first()
        |> Map.get("k")

      assert k.labels == ["Person"]
      assert k.properties["name"] == "Kote"
    end

    @tag :core
    test "query/2 and query!/2", c do
      assert r = Boltx.query!(c.conn, "RETURN [10,11,21] AS arr")
      assert [10, 11, 21] = Response.first(r)["arr"]

      assert {:ok, %Response{} = r} = Boltx.query(c.conn, "RETURN [10,11,21] AS arr")
      assert [10, 11, 21] = Response.first(r)["arr"]
    end

    @tag :core
    test "create a Bob node and check it was deleted afterwards", c do
      assert %Response{stats: stats} =
               Boltx.query!(c.conn, "CREATE (a:Person {name:'Bob'})")

      assert stats["labels-added"] == 1
      assert stats["nodes-created"] == 1
      assert stats["properties-set"] == 1

      assert ["Bob"] ==
               Boltx.query!(c.conn, "MATCH (a:Person {name: 'Bob'}) RETURN a.name AS name")
               |> Enum.map(& &1["name"])

      assert %Response{stats: stats} =
               Boltx.query!(c.conn, "MATCH (a:Person {name:'Bob'}) DELETE a")

      assert stats["nodes-deleted"] == 1
    end

    @tag :core
    test "can execute a query after a failure", c do
      assert {:error, _} = Boltx.query(c.conn, "INVALID CYPHER")
      assert {:ok, %Response{results: [%{"n" => 22}]}} = Boltx.query(c.conn, "RETURN 22 as n")
    end

    @tag :core
    test "negative numbers are returned as negative numbers", c do
      assert {:ok, %Response{results: [%{"n" => -1}]}} = Boltx.query(c.conn, "RETURN -1 as n")
    end

    @tag :core
    test "return a simple node", c do
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
             } = Boltx.query!(c.conn, "MATCH (p:Person {name: 'Patrick Rothfuss'}) RETURN p")
    end

    @tag :core
    test "Simple relationship", c do
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
             } = Boltx.query!(c.conn, cypher)
    end

    @tag :core
    test "simple path", c do
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
                         id: _,
                         properties: %{},
                         type: "KNOWS"
                       }
                     ],
                     sequence: [1, 1]
                   }
                 }
               ]
             } = Boltx.query!(c.conn, cypher)
    end

    @tag :bolt_3_x
    @tag :bolt_4_x
    @tag :bolt_5_x
    test "Cypher with plan resul", c do
      assert %Response{plan: plan} = Boltx.query!(c.conn, "EXPLAIN RETURN 1")
      refute plan == nil
      assert Regex.match?(~r/[3|4|5]/iu, plan["args"]["planner-version"])
    end

    @tag :bolt_3_x
    @tag :bolt_4_x
    @tag :bolt_5_x
    test "EXPLAIN MATCH (n), (m) RETURN n, m", c do
      assert %Response{notifications: notifications, plan: plan} =
               Boltx.query!(c.conn, "EXPLAIN MATCH (n), (m) RETURN n, m")

      refute notifications == nil
      refute plan == nil

      if Regex.match?(~r/CYPHER 3/iu, plan["args"]["planner-version"]) do
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

    @tag :bolt_2_x
    @tag :bolt_3_x
    @tag :bolt_4_x
    @tag :bolt_5_x
    test "transform Point in cypher-compliant data", c do
      query = "RETURN point($point_data) AS pt"
      params = %{point_data: Point.create(:cartesian, 50, 60.5)}

      assert {:ok, %Response{results: res}} = Boltx.query(c.conn, query, params)

      assert res == [
               %{
                 "pt" => %Boltx.Types.Point{
                   crs: "cartesian",
                   height: nil,
                   latitude: nil,
                   longitude: nil,
                   srid: 7203,
                   x: 50.0,
                   y: 60.5,
                   z: nil
                 }
               }
             ]
    end

    @tag :bolt_2_x
    @tag :bolt_3_x
    @tag :bolt_4_x
    @tag :bolt_5_x
    test "transform Duration in cypher-compliant data", c do
      query = "RETURN duration($d) AS d"

      params = %{
        d: %Duration{
          days: 0,
          hours: 0,
          minutes: 54,
          months: 12,
          nanoseconds: 0,
          seconds: 65,
          weeks: 0,
          years: 1
        }
      }

      expected = %Duration{
        days: 0,
        hours: 0,
        minutes: 55,
        months: 0,
        nanoseconds: 0,
        seconds: 5,
        weeks: 0,
        years: 2
      }

      assert {:ok, %Response{results: [%{"d" => ^expected}]}} = Boltx.query(c.conn, query, params)
    end
  end

  defp connect(c) do
    {:ok, conn} = Boltx.start_link(@opts)
    Map.put(c, :conn, conn)
  end

  defp truncate(c) do
    Boltx.query!(c.conn, "MATCH (n) DETACH DELETE n")
    c
  end

  defp rebuild_fixtures(c) do
    Boltx.Test.Fixture.create_graph(c.conn, :boltx)
    c
  end
end
