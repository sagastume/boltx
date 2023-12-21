defmodule BoltxTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Boltx.Response

  @opts Boltx.TestHelper.opts()

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
    test "a simple query to get nodes", c do
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
    test "a simple queries to get nodes with many queries", c do
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
