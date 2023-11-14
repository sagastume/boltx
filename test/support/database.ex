defmodule Boltx.Test.Support.Database do
  def clear(conn) do
    Boltx.query!(conn, "MATCH (n) DETACH DELETE n")
  end
end
