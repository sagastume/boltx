defmodule BoltxTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Boltx.Response

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
