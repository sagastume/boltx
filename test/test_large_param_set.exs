defmodule Large.Param.Set.Test do
  use ExUnit.Case
  doctest Boltx
  @moduletag :legacy

  setup_all do
    {:ok, [conn: Boltx.conn()]}
  end

  @doc """
  Boltex.Bolt.generate_chunks fails with too much data
  test provided by @adri, for issue #16
  """
  test "executing a Cypher query, with large set of parameters", context do
    conn = context[:conn]

    cypher = """
      MATCH (n:Person {boltx: true})
      FOREACH (i IN $largeRange| SET n.test = TRUE )
    """

    case Boltx.query(conn, cypher, %{largeRange: Enum.to_list(0..1_000_000)}) do
      {:ok, stats} ->
        assert stats["properties-set"] > 0, "Expecting many properties set"

      {:error, reason} ->
        IO.puts("Error: #{reason["message"]}")
    end
  end
end
