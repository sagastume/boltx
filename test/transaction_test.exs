defmodule Transaction.Test do
  use ExUnit.Case, async: true

  alias Boltx.Response

  setup do
    {:ok, [main_conn: Boltx.conn()]}
  end

  test "execute statements in transaction", %{main_conn: main_conn} do
    Boltx.transaction(main_conn, fn conn ->
      book =
        Boltx.query!(conn, "CREATE (b:Book {title: \"The Game Of Trolls\"}) return b")
        |> Response.first()

      assert %{"b" => g_o_t} = book
      assert g_o_t.properties["title"] == "The Game Of Trolls"
      Boltx.rollback(conn, :changed_my_mind)
    end)

    books = Boltx.query!(main_conn, "MATCH (b:Book {title: \"The Game Of Trolls\"}) return b")
    assert Enum.count(books) == 0
  end

  ###
  ### NOTE:
  ###
  ### The labels used in these examples MUST be unique across all tests!
  ### These tests depend on being able to expect that a node either exists
  ### or does not, and asynchronous testing with the same names will cause
  ### random cases where the underlying state changes.
  ###

  test "rollback statements in transaction", %{main_conn: main_conn} do
    try do
      # In case there's already a copy in our DB, count them...
      {:ok, %Response{results: [result]}} =
        Boltx.query(main_conn, "MATCH (x:XactRollback) RETURN count(x)")

      original_count = result["count(x)"]

      Boltx.transaction(main_conn, fn conn ->
        assert {:ok, %Response{results: [row]}} =
                 Boltx.query(
                   conn,
                   "CREATE (x:XactRollback {title:\"The Game Of Trolls\"}) return x"
                 )

        assert row["x"].properties["title"] == "The Game Of Trolls"

        # Original connection (outside the transaction) should not see this node.
        assert {:ok, %Response{results: [result]}} =
                 Boltx.query(main_conn, "MATCH (x:XactRollback) RETURN count(x)")

        assert result["count(x)"] == original_count,
               "Main connection should not be able to see transactional change"

        Boltx.rollback(conn, :changed_my_mind)
      end)

      # Original connection should still not see this node committed.
      assert {:ok, %Response{results: [result]}} =
               Boltx.query(main_conn, "MATCH (x:XactRollback) RETURN count(x)")

      assert result["count(x)"] == original_count
    after
      # Delete all XactRollback nodes in case the rollback() didn't work!
      Boltx.query(main_conn, "MATCH (x:XactRollback) DETACH DELETE x")
    end
  end

  test "commit statements in transaction", %{main_conn: main_conn} do
    try do
      Boltx.transaction(main_conn, fn conn ->
        assert {:ok, %Response{results: books}} =
                 Boltx.query(conn, "CREATE (x:XactCommit {foo: 'bar'}) return x")

        # TODO: maybe we can make Entity implement Access? That will avoid the Map gets below
        assert "bar" ==
                 books
                 |> List.first()
                 |> Map.get("x")
                 |> Map.get(:properties)
                 |> Map.get("foo")

        # Main connection should not see this new node.
        {:ok, %Response{results: results}} =
          Boltx.query(main_conn, "MATCH (x:XactCommit) RETURN x")

        assert is_list(results)

        assert Enum.count(results) == 0,
               "Main connection should not be able to see transactional changes"
      end)

      # And we should see it now with the main connection.
      {:ok, %Response{results: [%{"x" => node}]}} =
        Boltx.query(main_conn, "MATCH (x:XactCommit) RETURN x")

      assert node.labels == ["XactCommit"]
      assert node.properties["foo"] == "bar"
    after
      # Delete any XactCommit nodes that were succesfully committed!
      Boltx.query(main_conn, "MATCH (x:XactCommit) DETACH DELETE x")
    end
  end
end
