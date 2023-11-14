defmodule Boltx.ConnCase do
  use ExUnit.CaseTemplate

  setup_all do
    Boltx.start_link(Application.get_env(:boltx, Bolt))
    conn = Boltx.conn()

    on_exit(fn ->
      Boltx.Test.Support.Database.clear(conn)
    end)

    {:ok, conn: conn}
  end
end
