defmodule Boltx.ResultStreamingIntegrationTest do
  @moduledoc """
  Integration tests for Result streaming with live Neo4j connection.
  These tests require a running Neo4j instance.

  Run with: mix test test/integration/result_streaming_integration_test.exs

  Tests will fail if Neo4j is not available.
  """
  use ExUnit.Case

  alias Boltx.Response
  alias Boltx.Client

  @moduletag :integration

  setup_all do
    # Connect to Neo4j (will fail tests if not available)
    {:ok, client} = connect_to_neo4j()

    # Clean up any existing test data
    cleanup_test_data(client)

    on_exit(fn ->
      cleanup_test_data(client)
      Client.disconnect(client)
    end)

    {:ok, client: client}
  end

  describe "stream with live Neo4j connection" do
    @tag :integration
    test "streams large result sets efficiently", %{client: client} do
      # Create a large result set
      query = "UNWIND range(1, 5000) AS n RETURN n, n * 2 AS doubled"

      {:ok, result} = Client.run_statement(client, query, %{}, %{})
      response = Response.new(result)

      # Stream and verify we can process all results
      results = response |> Response.stream() |> Enum.to_list()

      assert length(results) == 5000
      assert Enum.at(results, 0)["n"] == 1
      assert Enum.at(results, 0)["doubled"] == 2
      assert Enum.at(results, 4999)["n"] == 5000
      assert Enum.at(results, 4999)["doubled"] == 10000
    end

    @tag :integration
    test "supports early termination", %{client: client} do
      query = "UNWIND range(1, 10000) AS n RETURN n"

      {:ok, result} = Client.run_statement(client, query, %{}, %{})
      response = Response.new(result)

      # Take only 100 records
      results = response |> Response.stream() |> Enum.take(100)

      assert length(results) == 100
      assert Enum.at(results, 0)["n"] == 1
      assert Enum.at(results, 99)["n"] == 100
    end

    @tag :integration
    test "works with Stream operations for filtering and mapping", %{client: client} do
      query = "UNWIND range(1, 1000) AS n RETURN n"

      {:ok, result} = Client.run_statement(client, query, %{}, %{})
      response = Response.new(result)

      # Filter even numbers and multiply by 10
      results =
        response
        |> Response.stream()
        |> Stream.filter(fn record -> rem(record["n"], 2) == 0 end)
        |> Stream.map(fn record -> record["n"] * 10 end)
        |> Enum.take(10)

      assert results == [20, 40, 60, 80, 100, 120, 140, 160, 180, 200]
    end

    @tag :integration
    test "handles empty result sets", %{client: client} do
      query = "RETURN 1 AS n LIMIT 0"

      {:ok, result} = Client.run_statement(client, query, %{}, %{})
      response = Response.new(result)

      results = response |> Response.stream() |> Enum.to_list()

      assert results == []
    end

    @tag :integration
    test "processes results in chunks efficiently", %{client: client} do
      query = "UNWIND range(1, 10000) AS n RETURN n"

      {:ok, result} = Client.run_statement(client, query, %{}, %{})
      response = Response.new(result)

      # Process in chunks of 500
      chunk_sums =
        response
        |> Response.stream()
        |> Stream.chunk_every(500)
        |> Stream.map(fn chunk ->
          Enum.reduce(chunk, 0, fn record, acc -> acc + record["n"] end)
        end)
        |> Enum.to_list()

      assert length(chunk_sums) == 20
      # Sum of 1..10000 = 50,005,000
      assert Enum.sum(chunk_sums) == 50_005_000
    end

    @tag :integration
    test "handles complex nested structures", %{client: client} do
      # Create some test nodes
      setup_query = """
      CREATE (alice:Person {name: 'Alice', age: 30})
      CREATE (bob:Person {name: 'Bob', age: 25})
      CREATE (charlie:Person {name: 'Charlie', age: 35})
      CREATE (alice)-[:KNOWS]->(bob)
      CREATE (bob)-[:KNOWS]->(charlie)
      """

      {:ok, _} = Client.run_statement(client, setup_query, %{}, %{})

      # Query with nested structures
      query = """
      MATCH (p:Person)
      OPTIONAL MATCH (p)-[:KNOWS]->(friend:Person)
      RETURN p.name AS name, p.age AS age, collect(friend.name) AS friends
      ORDER BY p.name
      """

      {:ok, result} = Client.run_statement(client, query, %{}, %{})
      response = Response.new(result)

      results = response |> Response.stream() |> Enum.to_list()

      assert length(results) == 3
      alice = Enum.find(results, fn r -> r["name"] == "Alice" end)
      assert alice["age"] == 30
      assert alice["friends"] == ["Bob"]
    end

    @tag :integration
    test "memory efficiency - doesn't load all records at once", %{client: client} do
      # Create a very large result set
      query = "UNWIND range(1, 100000) AS n RETURN n"

      {:ok, result} = Client.run_statement(client, query, %{}, %{})
      response = Response.new(result)

      # Process with early termination - should be fast and memory efficient
      {time_microseconds, result_sum} =
        :timer.tc(fn ->
          response
          |> Response.stream()
          |> Stream.map(fn record -> record["n"] end)
          |> Enum.take(1000)
          |> Enum.sum()
        end)

      # Sum of 1..1000
      assert result_sum == 500_500

      # Should complete quickly (less than 1 second)
      assert time_microseconds < 1_000_000,
             "Streaming should be fast, took #{time_microseconds / 1000}ms"
    end
  end

  # Helper functions

  defp connect_to_neo4j do
    opts = Boltx.TestHelper.opts()

    case Client.connect(opts) do
      {:ok, client} ->
        # Perform handshake based on bolt version
        case client.bolt_version do
          version when version >= 5.1 ->
            Client.send_hello(client, opts)
            Client.send_logon(client, opts)

          version when version >= 3.0 ->
            Client.send_hello(client, opts)

          version when version <= 2.0 ->
            Client.send_init(client, opts)
        end

        # Now ping should work
        case Client.send_ping(client) do
          {:ok, true} -> {:ok, client}
          _ -> {:error, :ping_failed}
        end

      error ->
        error
    end
  end

  defp cleanup_test_data(client) do
    # Clean up any test nodes
    query = "MATCH (p:Person) DETACH DELETE p"
    Client.run_statement(client, query, %{}, %{})
    :ok
  end
end
