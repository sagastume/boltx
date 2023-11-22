defmodule Boltx.InvalidParamType.Test do
  use ExUnit.Case

  setup_all do
    Boltx.ConnectionSupervisor.connections()
    {:ok, [conn: Boltx.conn()]}
  end

  test "executing a Cypher query, with invalid parameter value yields an error", context do
    conn = context[:conn]

    cypher = """
      MATCH (n:Person {invalid: {an_elixir_datetime}}) RETURN TRUE
    """

    {:error, %Boltx.ErrorLegacy{message: message}} =
      Boltx.query(conn, cypher, %{an_elixir_tuple: {:not, :valid}})

    assert String.match?(message, ~r/unable to encode value: {:not, :valid}/i)
  end
end
