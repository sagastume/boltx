defmodule Boltx.ConnectionTest do
  use ExUnit.Case, async: false

  alias Boltx.Connection
  alias Boltx.BoltProtocol.Versions

  @opts Boltx.TestHelper.opts()
  @opts_without_auth Boltx.TestHelper.opts_without_auth()

  @tag core: true
  test "connect/1 - disconnect/1 successful" do
    assert {:ok,
            %Connection{
              client: client,
              server_version: server_version,
              connection_id: connection_id
            } = conn_data} =
             Connection.connect(@opts)

    assert is_bitstring(server_version)
    assert is_bitstring(connection_id)
    assert is_float(client.bolt_version)
    assert :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag core: true
  test "connect/1 - not successful with incorrect credentials" do
    opts = @opts_without_auth ++ [auth: [username: "baduser", password: "badsecret"]]

    {:error, %Boltx.Error{code: :unauthorized}} =
      Connection.connect(opts)
  end

  @tag core: true
  test "checkout/1 successful" do
    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(@opts)

    assert is_bitstring(server_version)
    assert is_bitstring(connection_id)
    assert is_float(client.bolt_version)

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkout(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag core: true
  test "checkin/1 successful" do
    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(@opts)

    assert is_bitstring(server_version)
    assert is_bitstring(connection_id)
    assert is_float(client.bolt_version)

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkin(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag :core
  test "connect/1 fails when connection is not available" do
    opts = [
      hostname: "192.0.0.198",
      connect_timeout: 1,
      auth: [username: "baduser"]
    ]

    assert {:error, %Boltx.Error{code: :timeout}} = Connection.connect(opts)
  end

  @tag :bolt_version_1_0
  test "connect/1 successful with bolt version 1.0" do
    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(@opts)

    assert server_version == "Neo4j/3.4.0"
    assert client.bolt_version == 1.0
    assert is_bitstring(connection_id)

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkin(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag :bolt_version_2_0
  test "connect/1 successful with bolt version 2.0" do
    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(@opts)

    assert server_version == "Neo4j/3.4.0"
    assert client.bolt_version == 2.0
    assert is_bitstring(connection_id)

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkin(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag :bolt_version_3_0
  test "connect/1 successful with bolt version 3.0" do
    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(@opts)

    assert server_version == "Neo4j/4.4.27"
    assert client.bolt_version == 3.0
    assert is_bitstring(connection_id)
    assert String.contains?(connection_id, "bolt-")

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkin(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag :bolt_version_4_0
  test "connect/1 successful with bolt version 4.0" do
    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(@opts)

    assert server_version == "Neo4j/4.4.27"
    assert client.bolt_version == 4.0
    assert is_bitstring(connection_id)
    assert String.contains?(connection_id, "bolt-")

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkin(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag :bolt_version_4_1
  test "connect/1 successful with bolt version 4.1" do
    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(@opts)

    assert server_version == "Neo4j/4.4.27"
    assert client.bolt_version == 4.1
    assert is_bitstring(connection_id)
    assert String.contains?(connection_id, "bolt-")

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkin(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag :bolt_version_4_2
  test "connect/1 successful with bolt version 4.2" do
    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(@opts)

    assert server_version == "Neo4j/4.4.27"
    assert client.bolt_version == 4.2
    assert is_bitstring(connection_id)
    assert String.contains?(connection_id, "bolt-")

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkin(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag :bolt_version_4_3
  test "connect/1 successful with bolt version 4.3" do
    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(@opts)

    assert server_version == "Neo4j/4.4.27"
    assert client.bolt_version == 4.3
    assert is_bitstring(connection_id)
    assert String.contains?(connection_id, "bolt-")

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkin(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag :bolt_version_4_4
  test "connect/1 successful with bolt version 4.4" do
    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(@opts)

    assert server_version == "Neo4j/4.4.27"
    assert client.bolt_version == 4.4
    assert is_bitstring(connection_id)
    assert String.contains?(connection_id, "bolt-")

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkin(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag :bolt_version_5_0
  test "connect/1 successful with bolt version 5.0" do
    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(@opts)

    assert server_version == "Neo4j/5.13.0"
    assert client.bolt_version == 5.0
    assert is_bitstring(connection_id)
    assert String.contains?(connection_id, "bolt-")

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkin(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag :bolt_version_5_1
  test "connect/1 successful with bolt version 5.1" do
    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(@opts)

    assert server_version == "Neo4j/5.13.0"
    assert client.bolt_version == 5.1
    assert is_bitstring(connection_id)
    assert String.contains?(connection_id, "bolt-")

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkin(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag :bolt_version_5_2
  test "connect/1 successful with bolt version 5.2" do
    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(@opts)

    assert server_version == "Neo4j/5.13.0"
    assert client.bolt_version == 5.2
    assert is_bitstring(connection_id)
    assert String.contains?(connection_id, "bolt-")

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkin(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag :bolt_version_5_3
  test "connect/1 successful with bolt version 5.3" do
    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(@opts)

    assert server_version == "Neo4j/5.13.0"
    assert client.bolt_version == 5.3
    assert is_bitstring(connection_id)
    assert String.contains?(connection_id, "bolt-")

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkin(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag :bolt_version_5_4
  test "connect/1 successful with bolt version 5.4" do
    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(@opts)

    assert server_version == "Neo4j/5.13.0"
    assert client.bolt_version == 5.4
    assert is_bitstring(connection_id)
    assert String.contains?(connection_id, "bolt-")

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkin(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end

  @tag :last_version
  test "connect/1 successful with specific bolt version" do
    last_version = List.last(Versions.available_versions())
    opts = [versions: [last_version]] ++ @opts

    {:ok,
     %Connection{client: client, server_version: server_version, connection_id: connection_id} =
       conn_data} =
      Connection.connect(opts)

    assert server_version == "Neo4j/5.13.0"
    assert client.bolt_version == last_version
    assert is_bitstring(connection_id)
    assert String.contains?(connection_id, "bolt-")

    assert {:ok, %Connection{client: _} = conn_data} =
             Connection.checkin(conn_data)

    :ok = Connection.disconnect(:stop, conn_data)
  end
end
