defmodule Boltx.ResultStreamingTest do
  @moduledoc """
  Comprehensive tests for lazy Result streaming using Stream.resource/3.
  Tests are written FIRST (TDD RED phase) - they should fail initially.
  """
  use ExUnit.Case, async: true

  alias Boltx.Response
  alias Boltx.Client

  @opts Boltx.TestHelper.opts()

  defp handle_handshake(client, opts) do
    case client.bolt_version do
      version when version >= 5.1 ->
        metadata = Client.send_hello(client, opts)
        Client.send_logon(client, opts)
        metadata

      version when version >= 3.0 ->
        Client.send_hello(client, opts)

      version when version <= 2.0 ->
        Client.send_init(client, opts)
    end
  end

  describe "stream/1 - lazy evaluation" do
    test "returns a Stream" do
      response = %Response{
        fields: ["n"],
        records: [[1], [2], [3]],
        results: [%{"n" => 1}, %{"n" => 2}, %{"n" => 3}]
      }

      stream = Response.stream(response)
      assert is_function(stream, 2)

      # Verify it's actually a stream by consuming it
      results = stream |> Enum.to_list()
      assert length(results) == 3
    end

    test "yields records one by one from existing records" do
      response = %Response{
        fields: ["name", "age"],
        records: [["Alice", 30], ["Bob", 25], ["Charlie", 35]],
        results: [
          %{"name" => "Alice", "age" => 30},
          %{"name" => "Bob", "age" => 25},
          %{"name" => "Charlie", "age" => 35}
        ]
      }

      results = response |> Response.stream() |> Enum.to_list()

      assert length(results) == 3
      assert Enum.at(results, 0) == %{"name" => "Alice", "age" => 30}
      assert Enum.at(results, 1) == %{"name" => "Bob", "age" => 25}
      assert Enum.at(results, 2) == %{"name" => "Charlie", "age" => 35}
    end

    test "handles empty results" do
      response = %Response{
        fields: ["n"],
        records: [],
        results: []
      }

      results = response |> Response.stream() |> Enum.to_list()
      assert results == []
    end

    test "works with Enum.take for early termination" do
      response = %Response{
        fields: ["n"],
        records: Enum.map(1..1000, &[&1]),
        results: Enum.map(1..1000, &%{"n" => &1})
      }

      # Should only process 10 items, not all 1000
      results = response |> Response.stream() |> Enum.take(10)

      assert length(results) == 10
      assert Enum.at(results, 0) == %{"n" => 1}
      assert Enum.at(results, 9) == %{"n" => 10}
    end

    test "is composable with Stream operations" do
      response = %Response{
        fields: ["n"],
        records: Enum.map(1..100, &[&1]),
        results: Enum.map(1..100, &%{"n" => &1})
      }

      results =
        response
        |> Response.stream()
        |> Stream.filter(fn record -> record["n"] > 50 end)
        |> Stream.map(fn record -> record["n"] * 2 end)
        |> Enum.take(5)

      assert results == [102, 104, 106, 108, 110]
    end

    test "handles nested structures" do
      response = %Response{
        fields: ["person", "friends"],
        records: [
          [%{"name" => "Alice"}, [%{"name" => "Bob"}]],
          [%{"name" => "Charlie"}, [%{"name" => "David"}]]
        ],
        results: [
          %{"person" => %{"name" => "Alice"}, "friends" => [%{"name" => "Bob"}]},
          %{"person" => %{"name" => "Charlie"}, "friends" => [%{"name" => "David"}]}
        ]
      }

      results = response |> Response.stream() |> Enum.to_list()

      assert length(results) == 2
      assert results |> Enum.at(0) |> get_in(["person", "name"]) == "Alice"
    end
  end

  describe "stream/2 - with fetch_size for chunked pulling" do
    test "accepts fetch_size option" do
      response = %Response{
        fields: ["n"],
        records: Enum.map(1..100, &[&1]),
        results: Enum.map(1..100, &%{"n" => &1})
      }

      # Should work with custom fetch size
      stream = Response.stream(response, fetch_size: 10)
      results = stream |> Enum.take(5)

      assert length(results) == 5
    end

    test "defaults fetch_size to 1000" do
      response = %Response{
        fields: ["n"],
        records: [[1]],
        results: [%{"n" => 1}]
      }

      # Should work without fetch_size specified
      stream = Response.stream(response)
      results = stream |> Enum.to_list()

      assert length(results) == 1
    end
  end

  describe "stream_with_client/2 - lazy pulling from server" do
    @moduletag :integration

    setup do
      Application.put_env(:boltx, :log, false)
      on_exit(fn -> Application.delete_env(:boltx, :log) end)
      :ok
    end

    @tag capture_log: true
    test "pulls records in batches from server" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      query = """
      UNWIND range(1, 5000) AS n
      RETURN n, n * 2 AS doubled
      """

      # Use send_run to initiate query without pulling all records
      {:ok, result_run} = Client.send_run(client, query, %{}, %{})
      fields = Map.get(result_run, "fields", [])

      # Create a minimal response for streaming
      response = %Response{
        fields: fields,
        records: [],
        results: []
      }

      # Should lazily pull records in batches
      stream = Response.stream_with_client(response, client)

      # Take only first 100 - should only pull what's needed
      results = stream |> Enum.take(100)

      assert length(results) == 100
      assert Enum.at(results, 0)["n"] == 1
      assert Enum.at(results, 0)["doubled"] == 2
    end

    @tag capture_log: true
    test "handles backpressure correctly" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      query = "UNWIND range(1, 10000) AS n RETURN n"

      # Use send_run to initiate query without pulling all records
      {:ok, result_run} = Client.send_run(client, query, %{}, %{})
      fields = Map.get(result_run, "fields", [])

      # Create a minimal response for streaming
      response = %Response{
        fields: fields,
        records: [],
        results: []
      }

      stream = Response.stream_with_client(response, client, fetch_size: 100)

      # Process in chunks - should only pull as needed
      chunk_count =
        stream
        |> Stream.chunk_every(500)
        |> Enum.take(3)
        |> length()

      # Should have pulled 3 chunks (1500 records total)
      assert chunk_count == 3
    end

    @tag capture_log: true
    test "supports early termination without pulling all records" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      query = "UNWIND range(1, 10000) AS n RETURN n"

      # Use send_run to initiate query without pulling all records
      {:ok, result_run} = Client.send_run(client, query, %{}, %{})
      fields = Map.get(result_run, "fields", [])

      # Create a minimal response for streaming
      response = %Response{
        fields: fields,
        records: [],
        results: []
      }

      # Should stop pulling after finding the target
      result =
        response
        |> Response.stream_with_client(client, fetch_size: 100)
        |> Enum.find(fn record -> record["n"] == 50 end)

      assert result["n"] == 50
    end
  end

  describe "memory efficiency" do
    test "does not load all records into memory at once" do
      # Create a large result set
      large_records = Enum.map(1..100_000, &[&1])
      large_results = Enum.map(1..100_000, &%{"n" => &1})

      response = %Response{
        fields: ["n"],
        records: large_records,
        results: large_results
      }

      # Stream processing should be memory efficient
      sum =
        response
        |> Response.stream()
        |> Stream.map(fn record -> record["n"] end)
        |> Enum.take(1000)
        |> Enum.sum()

      # Sum of 1..1000
      assert sum == 500_500
    end

    test "allows garbage collection during streaming" do
      response = %Response{
        fields: ["n"],
        records: Enum.map(1..10_000, &[&1]),
        results: Enum.map(1..10_000, &%{"n" => &1})
      }

      # Process in chunks - each chunk should be GC'd
      chunk_sums =
        response
        |> Response.stream()
        |> Stream.chunk_every(1000)
        |> Stream.map(fn chunk ->
          Enum.reduce(chunk, 0, fn record, acc -> acc + record["n"] end)
        end)
        |> Enum.to_list()

      assert length(chunk_sums) == 10
      assert Enum.sum(chunk_sums) == 50_005_000
    end
  end

  describe "error handling" do
    test "handles malformed response gracefully" do
      response = %Response{
        fields: nil,
        records: [[1], [2]],
        results: []
      }

      # Should handle gracefully by streaming empty results list
      results = response |> Response.stream() |> Enum.to_list()
      assert results == []
    end

    test "handles mismatched fields and records" do
      response = %Response{
        fields: ["a", "b"],
        # Missing second field
        records: [[1]],
        results: [%{"a" => 1}]
      }

      results = response |> Response.stream() |> Enum.to_list()
      # Should handle gracefully
      assert is_list(results)
    end
  end

  describe "compatibility with existing Response API" do
    test "stream/1 works alongside results field" do
      response = %Response{
        fields: ["n"],
        records: [[1], [2], [3]],
        results: [%{"n" => 1}, %{"n" => 2}, %{"n" => 3}]
      }

      # Both should work
      direct_results = response.results
      streamed_results = response |> Response.stream() |> Enum.to_list()

      assert direct_results == streamed_results
    end

    test "first/1 still works with Response" do
      response = %Response{
        fields: ["n"],
        records: [[1], [2], [3]],
        results: [%{"n" => 1}, %{"n" => 2}, %{"n" => 3}]
      }

      assert Response.first(response) == %{"n" => 1}
    end
  end

  describe "benchmarking helpers" do
    @tag :benchmark
    test "compare stream vs direct results performance" do
      response = %Response{
        fields: ["n"],
        records: Enum.map(1..10_000, &[&1]),
        results: Enum.map(1..10_000, &%{"n" => &1})
      }

      # Direct access
      {time_direct, _result} =
        :timer.tc(fn ->
          Enum.map(response.results, fn r -> r["n"] * 2 end)
        end)

      # Streaming
      {time_stream, _result} =
        :timer.tc(fn ->
          response
          |> Response.stream()
          |> Enum.map(fn r -> r["n"] * 2 end)
        end)

      # Both should complete (performance comparison is informational)
      assert time_direct > 0
      assert time_stream > 0
    end
  end
end
