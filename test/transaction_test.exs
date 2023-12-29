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
    setup [:connect, :truncate]

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
