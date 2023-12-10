defmodule Boltx.ProtocolTest do
  use ExUnit.Case, async: false

  alias Boltx.Protocol
  @moduletag :legacy

  # Transactions are not tested as BEGIN fails
  # But works fine from Boltx.transaction

  test "connect/1 - disconnect/1 successful" do
    assert {:ok, %Protocol.ConnData{sock: _, bolt_version: _, configuration: _} = conn_data} =
             Protocol.connect([])

    assert :ok = Protocol.disconnect(:stop, conn_data)
  end

  test "checkout/1 successful" do
    {:ok, %Protocol.ConnData{sock: _, bolt_version: _, configuration: _} = conn_data} =
      Protocol.connect([])

    assert {:ok, %Protocol.ConnData{sock: _, bolt_version: _, configuration: _} = conn_data} =
             Protocol.checkout(conn_data)

    :ok = Protocol.disconnect(:stop, conn_data)
  end

  test "checkin/1 successful" do
    {:ok, %Protocol.ConnData{sock: _, bolt_version: _, configuration: _} = conn_data} =
      Protocol.connect([])

    assert {:ok, %Protocol.ConnData{sock: _, bolt_version: _, configuration: _} = conn_data} =
             Protocol.checkin(conn_data)

    :ok = Protocol.disconnect(:stop, conn_data)
  end
end
