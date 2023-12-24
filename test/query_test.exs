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
