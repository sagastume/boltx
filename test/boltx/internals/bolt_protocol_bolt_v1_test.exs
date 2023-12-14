defmodule Boltx.Internals.BoltProtocolV1Test do
  use Boltx.InternalCase
  @moduletag :bolt_v1
  alias Boltx.Internals.BoltProtocol

  @moduletag :legacy

  test "works within a transaction", %{port: port, bolt_version: bolt_version} do
    assert [{:success, _}, {:success, _}] =
             BoltProtocol.run_statement(:gen_tcp, port, bolt_version, "BEGIN")

    assert [{:success, _} | _] =
             BoltProtocol.run_statement(:gen_tcp, port, bolt_version, "RETURN 1 as num")

    assert [{:success, _}, {:success, _}] =
             BoltProtocol.run_statement(:gen_tcp, port, bolt_version, "COMMIT")
  end

  test "works with rolled-back transactions", %{port: port, bolt_version: bolt_version} do
    assert [{:success, _}, {:success, _}] =
             BoltProtocol.run_statement(:gen_tcp, port, bolt_version, "BEGIN")

    assert [{:success, _} | _] =
             BoltProtocol.run_statement(:gen_tcp, port, bolt_version, "RETURN 1 as num")

    assert [{:success, _}, {:success, _}] =
             BoltProtocol.run_statement(:gen_tcp, port, bolt_version, "ROLLBACK")
  end
end
