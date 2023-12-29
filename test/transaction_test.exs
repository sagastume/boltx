defmodule Transaction.Test do
  use ExUnit.Case, async: true

  alias Boltx.Response

  @opts Boltx.TestHelper.opts()

  ###
  ### NOTE:
  ###
  ### The labels used in these examples MUST be unique across all tests!
  ### These tests depend on being able to expect that a node either exists
  ### or does not, and asynchronous testing with the same names will cause
  ### random cases where the underlying state changes.
  ###

  describe "Transactions" do
    setup [:connect]

    @tag :core
    test "execute statements in transaction", c do
      Boltx.transaction(c.conn, fn conn ->
        book =
          Boltx.query!(
            conn,
            "CREATE (b:Book {title: \"The Game Of Trolls (B07V21Y4DJ)\"}) return b"
          )
          |> Response.first()

        assert %{"b" => g_o_t} = book
        assert g_o_t.properties["title"] == "The Game Of Trolls (B07V21Y4DJ)"
        Boltx.rollback(conn, :changed_my_mind)
      end)

      books =
        Boltx.query!(
          c.conn,
          "MATCH (b:Book {title: \"The Game Of Trolls (B07V21Y4DJ)\"}) return b"
        )

      assert Enum.count(books) == 0
    end

    @tag :core
    test "rollback statements in transaction", c do
      try do
        # In case there's already a copy in our DB, count them...
        {:ok, %Response{results: [result]}} =
          Boltx.query(c.conn, "MATCH (x:XactRollback) RETURN count(x)")

        original_count = result["count(x)"]

        Boltx.transaction(c.conn, fn conn ->
          assert {:ok, %Response{results: [row]}} =
                   Boltx.query(
                     conn,
                     "CREATE (x:XactRollback {title:\"The Game Of Trolls\"}) return x"
                   )

          assert row["x"].properties["title"] == "The Game Of Trolls"

          # Original connection (outside the transaction) should not see this node.
          assert {:ok, %Response{results: [result]}} =
                   Boltx.query(c.conn, "MATCH (x:XactRollback) RETURN count(x)")

          assert result["count(x)"] == original_count,
                 "Main connection should not be able to see transactional change"

          Boltx.rollback(conn, :changed_my_mind)
        end)

        # Original connection should still not see this node committed.
        assert {:ok, %Response{results: [result]}} =
                 Boltx.query(c.conn, "MATCH (x:XactRollback) RETURN count(x)")

        assert result["count(x)"] == original_count
      after
        # Delete all XactRollback nodes in case the rollback() didn't work!
        Boltx.query(c.conn, "MATCH (x:XactRollback) DETACH DELETE x")
      end
    end

    @tag :core
    test "commit statements in transaction", c do
      try do
        Boltx.transaction(c.conn, fn conn ->
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
            Boltx.query(c.conn, "MATCH (x:XactCommit) RETURN x")

          assert is_list(results)

          assert Enum.count(results) == 0,
                 "Main connection should not be able to see transactional changes"
        end)

        # And we should see it now with the main connection.
        {:ok, %Response{results: [%{"x" => node}]}} =
          Boltx.query(c.conn, "MATCH (x:XactCommit) RETURN x")

        assert node.labels == ["XactCommit"]
        assert node.properties["foo"] == "bar"
      after
        # Delete any XactCommit nodes that were succesfully committed!
        Boltx.query(c.conn, "MATCH (x:XactCommit) DETACH DELETE x")
      end
    end
  end

  defp connect(c) do
    opts = [pool_size: 2] ++ @opts
    {:ok, conn} = Boltx.start_link(opts)
    Map.put(c, :conn, conn)
  end
end
