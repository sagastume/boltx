defmodule Boltx.StreamingExampleTest do
  @moduledoc """
  Example demonstrating Result streaming usage.
  This test demonstrates the TDD approach and real-world usage patterns.
  """
  use ExUnit.Case, async: true

  alias Boltx.Response

  describe "Result Streaming Examples" do
    test "Example 1: Stream all results efficiently" do
      # Given a large result set (simulating a Neo4j query response)
      response = %Response{
        fields: ["id", "name", "value"],
        records: Enum.map(1..1000, fn i -> [i, "Item #{i}", i * 100] end),
        results:
          Enum.map(1..1000, fn i -> %{"id" => i, "name" => "Item #{i}", "value" => i * 100} end)
      }

      # When streaming through results
      processed =
        response
        |> Response.stream()
        |> Enum.map(fn record -> record["value"] end)
        |> Enum.sum()

      # Then we get the expected result
      # Sum of (1*100 + 2*100 + ... + 1000*100) = 100 * (1+2+...+1000) = 100 * 500500 = 50,050,000
      assert processed == 50_050_000
    end

    test "Example 2: Early termination with Enum.take" do
      # Given 10,000 records
      response = %Response{
        fields: ["n"],
        records: Enum.map(1..10_000, &[&1]),
        results: Enum.map(1..10_000, &%{"n" => &1})
      }

      # When taking only first 10
      results = response |> Response.stream() |> Enum.take(10)

      # Then only 10 records are processed
      assert length(results) == 10
      assert Enum.map(results, & &1["n"]) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    end

    test "Example 3: Filter and transform with Stream operations" do
      # Given a dataset
      response = %Response{
        fields: ["amount", "category"],
        records: [
          [100, "food"],
          [200, "transport"],
          [50, "food"],
          [300, "entertainment"],
          [75, "food"]
        ],
        results: [
          %{"amount" => 100, "category" => "food"},
          %{"amount" => 200, "category" => "transport"},
          %{"amount" => 50, "category" => "food"},
          %{"amount" => 300, "category" => "entertainment"},
          %{"amount" => 75, "category" => "food"}
        ]
      }

      # When filtering food expenses and summing
      total_food_expense =
        response
        |> Response.stream()
        |> Stream.filter(fn record -> record["category"] == "food" end)
        |> Stream.map(fn record -> record["amount"] end)
        |> Enum.sum()

      # Then we get correct total
      assert total_food_expense == 225
    end

    test "Example 4: Process in chunks for batch operations" do
      # Given a large dataset
      response = %Response{
        fields: ["id", "data"],
        records: Enum.map(1..1000, &[&1, "data_#{&1}"]),
        results: Enum.map(1..1000, &%{"id" => &1, "data" => "data_#{&1}"})
      }

      # When processing in chunks of 100
      chunk_ids =
        response
        |> Response.stream()
        |> Stream.chunk_every(100)
        |> Enum.map(fn chunk ->
          # Simulate batch processing (e.g., bulk insert)
          ids = Enum.map(chunk, & &1["id"])
          {Enum.min(ids), Enum.max(ids), length(ids)}
        end)

      # Then we get 10 chunks
      assert length(chunk_ids) == 10
      assert List.first(chunk_ids) == {1, 100, 100}
      assert List.last(chunk_ids) == {901, 1000, 100}
    end

    test "Example 5: Find first matching record" do
      # Given a large dataset
      response = %Response{
        fields: ["id", "status"],
        records: Enum.map(1..1000, &[&1, if(rem(&1, 123) == 0, do: "error", else: "ok")]),
        results:
          Enum.map(
            1..1000,
            &%{"id" => &1, "status" => if(rem(&1, 123) == 0, do: "error", else: "ok")}
          )
      }

      # When finding first error
      first_error =
        response
        |> Response.stream()
        |> Enum.find(fn record -> record["status"] == "error" end)

      # Then we find it efficiently without processing all records
      assert first_error["id"] == 123
      assert first_error["status"] == "error"
    end

    test "Example 6: Count matching records efficiently" do
      # Given a dataset
      response = %Response{
        fields: ["score"],
        records: Enum.map(1..1000, &[rem(&1, 10)]),
        results: Enum.map(1..1000, &%{"score" => rem(&1, 10)})
      }

      # When counting high scores (>= 7)
      high_score_count =
        response
        |> Response.stream()
        |> Stream.filter(fn record -> record["score"] >= 7 end)
        |> Enum.count()

      # Then we get accurate count
      # Numbers 7, 8, 9 appear 100 times each = 300 total
      assert high_score_count == 300
    end

    test "Example 7: Aggregate statistics" do
      # Given numerical data
      :rand.seed(:exsplus, {1, 2, 3})
      temps = Enum.map(1..100, fn _ -> 20 + :rand.uniform(10) end)

      response = %Response{
        fields: ["temperature"],
        records: Enum.map(temps, &[&1]),
        results: Enum.map(temps, &%{"temperature" => &1})
      }

      # When calculating statistics
      {count, sum, min_temp, max_temp} =
        response
        |> Response.stream()
        |> Enum.reduce({0, 0, 999, 0}, fn record, {cnt, sum, min_val, max_val} ->
          temp = record["temperature"]
          {cnt + 1, sum + temp, min(min_val, temp), max(max_val, temp)}
        end)

      avg = sum / count

      # Then we get valid statistics
      assert count == 100
      assert min_temp >= 21 and min_temp <= 30
      assert max_temp >= 21 and max_temp <= 30
      assert avg >= 20 and avg <= 31
    end

    test "Example 8: Memory efficiency comparison" do
      # Given a moderately large dataset
      large_response = %Response{
        fields: ["n"],
        records: Enum.map(1..50_000, &[&1]),
        results: Enum.map(1..50_000, &%{"n" => &1})
      }

      # Direct enumeration - loads all into memory
      direct_result = Enum.take(large_response.results, 100)

      # Streaming - lazy evaluation
      stream_result =
        large_response
        |> Response.stream()
        |> Enum.take(100)

      # Both should work and return the same results
      assert length(direct_result) == 100
      assert length(stream_result) == 100
      assert direct_result == stream_result
      # Both approaches are valid; streaming excels with truly large datasets
      # and when early termination is needed
    end
  end

  describe "Error handling examples" do
    test "handles empty results gracefully" do
      response = %Response{
        fields: ["n"],
        records: [],
        results: []
      }

      results = response |> Response.stream() |> Enum.to_list()
      assert results == []
    end

    test "handles single record" do
      response = %Response{
        fields: ["value"],
        records: [[42]],
        results: [%{"value" => 42}]
      }

      results = response |> Response.stream() |> Enum.to_list()
      assert results == [%{"value" => 42}]
    end
  end
end
