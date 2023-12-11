defmodule Boltx.PerformanceTest do
  use Boltx.ConnCase, async: false

  @moduletag :legacy

  setup(%{conn: conn} = context) do
    Boltx.Test.Support.Database.clear(conn)
    {:ok, context}
  end

  @tag :bench
  test "Querying 500 nodes should under 100ms", context do
    conn = context[:conn]

    cql_create =
      1..500
      |> Enum.map(fn x ->
        "CREATE (:Test {value: 'test_#{inspect(x)}'})"
      end)
      |> Enum.join("\n")

    assert %Boltx.Response{stats: %{"nodes-created" => 500}} =
             Boltx.query!(Boltx.conn(), cql_create)

    simple_cypher = """
      MATCH (t:Test)
      RETURN t AS test
    """

    output =
      Benchee.run(
        %{
          # "run" => fn -> query.(conn, simple_cypher) end
          "run" => fn -> Boltx.Query.query(conn, simple_cypher) end
          # " new conn" => fn -> query.(Boltx.conn(), simple_cypher) end
        },
        time: 5
      )

    # Query should take less than 50ms in average
    assert Enum.at(output.scenarios, 0).run_time_data.statistics.average < 125_000_000
  end

  @tag :bench
  test "Creating nodes with properties and a long list should take less than 100ms", context do
    conn = context[:conn]

    long_list = Enum.to_list(1..10_000)

    simple_cypher = """
      CREATE (t:Test $props)
      RETURN t AS test
    """

    output =
      Benchee.run(
        %{
          # "run" => fn -> query.(conn, simple_cypher) end
          "run with properties" => fn ->
            Boltx.Query.query(conn, simple_cypher, %{
              props: %{test_int: 124, test_float: 12.5, list: long_list}
            })
          end
          # " new conn" => fn -> query.(Boltx.conn(), simple_cypher) end
        },
        time: 5
      )

    # Query should take less than 50ms in average
    assert Enum.at(output.scenarios, 0).run_time_data.statistics.average < 125_000_000
  end
end
