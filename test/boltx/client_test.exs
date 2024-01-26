defmodule Boltx.ClientTest do
  use ExUnit.Case, async: true

  alias Boltx.Client
  alias Boltx.BoltProtocol.Versions
  import Boltx.BoltProtocol.ServerResponse

  @opts Boltx.TestHelper.opts()
  @noop_chunk <<0x00, 0x00>>

  defp handle_handshake(client, opts) do
    case client.bolt_version do
      version when version >= 5.1 ->
        metadata = Client.send_hello(client, opts)
        Client.send_logon(client, opts)
        metadata

      version when version >= 3.0 ->
        Client.send_hello(client, opts)

      version when version <= 2.0 ->
        Client.send_init(client, opts)
    end
  end

  describe "Client configuration" do
    @describetag :core

    test "parsing the host, schema and the port, from a uri string config parameter" do
      opts = [
        uri: "bolt://hobby-happyHoHoHo.dbs.graphenedb.com:24786",
        auth: [username: "usertest"]
      ]

      config = Client.Config.new(opts)

      assert config.hostname == "hobby-happyHoHoHo.dbs.graphenedb.com"
      assert config.scheme == "bolt"
      assert config.port == 24786
      assert config.username == "usertest"
    end

    test "standard Boltx default configuration for port, hostname and schema" do
      opts = [
        auth: [username: "usertest"]
      ]

      config = Client.Config.new(opts)

      assert config.hostname == "localhost"
      assert config.scheme == "bolt+s"
      assert config.username == "usertest"
    end

    test "parsing the host, scheme and the port without uri" do
      opts = [
        hostname: "hobby-happyHoHoHo.dbs.com",
        scheme: "bolt+s",
        port: 7689,
        auth: [username: "usertests"]
      ]

      config = Client.Config.new(opts)

      assert config.hostname == "hobby-happyHoHoHo.dbs.com"
      assert config.scheme == "bolt+s"
      assert config.port == 7689
      assert config.username == "usertests"
    end

    test "passing port, scheme and host along with uri" do
      opts = [
        uri: "bolt://hobby-happyHoHoHo.dbs.graphenedb.com:24786",
        hostname: "happy.com",
        scheme: "bolts",
        port: 7689,
        auth: [username: "usertests"]
      ]

      config = Client.Config.new(opts)

      assert config.hostname == "hobby-happyHoHoHo.dbs.graphenedb.com"
      assert config.scheme == "bolt"
      assert config.port == 24786
      assert config.username == "usertests"
    end

    test "returns correct values for different schemes" do
      base_opts = [
        auth: [username: "usertests"]
      ]

      opts1 = base_opts ++ [scheme: "bolt"]
      assert %Client.Config{scheme: "bolt", ssl?: false, ssl_opts: []} = Client.Config.new(opts1)

      opts2 = base_opts ++ [scheme: "bolt+s"]

      assert %Client.Config{scheme: "bolt+s", ssl?: true, ssl_opts: [verify: :verify_none]} =
               Client.Config.new(opts2)

      opts3 = base_opts ++ [scheme: "bolt+ssc"]

      assert %Client.Config{scheme: "bolt+ssc", ssl?: true, ssl_opts: [verify: :verify_peer]} =
               Client.Config.new(opts3)

      opts4 = base_opts ++ [scheme: "neo4j"]
      assert %Client.Config{scheme: "neo4j", ssl?: false, ssl_opts: []} = Client.Config.new(opts4)

      opts5 = base_opts ++ [scheme: "neo4j+s"]

      assert %Client.Config{scheme: "neo4j+s", ssl?: true, ssl_opts: [verify: :verify_none]} =
               Client.Config.new(opts5)

      opts6 = base_opts ++ [scheme: "neo4j+ssc"]

      assert %Client.Config{scheme: "neo4j+ssc", ssl?: true, ssl_opts: [verify: :verify_peer]} =
               Client.Config.new(opts6)
    end
  end

  describe "connect" do
    @tag :bolt_version_5_3
    test "multiple versions specified" do
      opts = [versions: [5.3, 4, 3]] ++ @opts
      assert {:ok, client} = Client.connect(opts)
      assert 5.3 == client.bolt_version
    end

    @tag :bolt_version_5_3
    test "unordered versions specified" do
      opts = [versions: [4, 3, 5.3]] ++ @opts
      assert {:ok, client} = Client.connect(opts)
      assert 5.3 == client.bolt_version
    end

    @tag :last_version
    test "no versions specified" do
      opts = [] ++ @opts
      assert {:ok, client} = Client.connect(opts)
      last_version = hd(Versions.latest_versions())
      assert last_version == client.bolt_version
    end

    @tag core: true
    test "zero version" do
      opts = [versions: [0]] ++ @opts
      {:error, %Boltx.Error{code: :version_negotiation_error}} = Client.connect(opts)
    end

    @tag core: true
    test "major version incompatible with the server" do
      opts = [versions: [50]] ++ @opts
      {:error, %Boltx.Error{code: :version_negotiation_error}} = Client.connect(opts)
    end

    @tag :bolt_version_1_0
    test "one version specified" do
      opts = [versions: [1]] ++ @opts
      assert {:ok, client} = Client.connect(opts)
      assert is_map(client)
      assert is_tuple(client.sock)
      assert 1.0 == client.bolt_version
    end
  end

  describe "recv_packets" do
    @tag core: true
    test "recv_packets concatenates and decodes one message in two chunks" do
      sizeMock = <<0, 10>>
      chunk1 = <<177, 14, 103, 106>>
      chunk2 = <<120, 5, 107, 108, 109, 15, 0, 0>>
      pid = Boltx.Mocks.SockMock.start_link([@noop_chunk, sizeMock <> chunk1, chunk2])
      client = %{sock: {Boltx.Mocks.SockMock, pid}, bolt_version: 1.0}
      {:ok, message} = Client.recv_packets(client, fn _bolt_version, data -> {:ok, data} end, 0)
      assert message == [chunk1 <> chunk2]
    end

    @tag core: true
    test "recv_packets decodes a message into a single chunk" do
      sizeMock = <<0, 4>>
      chunk1 = <<122, 14, 103, 106, 0, 0>>
      pid = Boltx.Mocks.SockMock.start_link([@noop_chunk, sizeMock <> chunk1])
      client = %{sock: {Boltx.Mocks.SockMock, pid}, bolt_version: 3.0}
      {:ok, message} = Client.recv_packets(client, fn _bolt_version, data -> {:ok, data} end, 0)
      assert message == [chunk1]
    end

    @tag core: true
    test "ignores noop chunks between two chunks" do
      sizeMock = <<0, 10>>
      chunk1 = <<177, 14, 103, 106>>
      chunk2 = <<120, 5, 107, 108, 109, 15, 0, 0>>

      pid =
        Boltx.Mocks.SockMock.start_link([
          @noop_chunk,
          sizeMock <> chunk1,
          @noop_chunk,
          chunk2,
          @noop_chunk
        ])

      client = %{sock: {Boltx.Mocks.SockMock, pid}, bolt_version: 5.0}
      {:ok, message} = Client.recv_packets(client, fn _bolt_version, data -> {:ok, data} end, 0)
      assert message == [chunk1 <> chunk2]
    end
  end

  describe "run_statement" do
    @tag core: true
    test "simple query" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      query = "RETURN 1024 AS a, 2048 AS b"

      {:ok,
       statement_result(
         result_run: result_run,
         result_pull: result_pull,
         query: query_result
       )} = Client.run_statement(client, query, %{}, %{})

      assert query_result == query
      assert %{"fields" => ["a", "b"], "t_first" => _} = result_run

      assert pull_result(records: records, success_data: success_data) = result_pull
      assert %{"t_last" => _, "type" => "r"} = success_data
      assert [[1024, 2048]] == records
    end

    @tag core: true
    test "simple query with parameters" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      query = "RETURN 4 + $number AS result"

      {:ok,
       statement_result(
         result_run: result_run,
         result_pull: result_pull,
         query: query_result
       )} = Client.run_statement(client, query, %{number: 5}, %{})

      assert query_result == query
      assert %{"fields" => ["result"], "t_first" => _} = result_run

      assert pull_result(records: records, success_data: success_data) = result_pull
      assert %{"t_last" => _, "type" => "r"} = success_data
      assert [[9]] == records
    end

    @tag core: true
    test "simple range query" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      query = "UNWIND range(1, 10) AS n RETURN n"

      {:ok,
       statement_result(
         result_run: result_run,
         result_pull: result_pull,
         query: query_result
       )} = Client.run_statement(client, query, %{}, %{})

      assert query_result == query
      assert %{"fields" => ["n"], "t_first" => _} = result_run

      assert pull_result(records: records, success_data: success_data) = result_pull
      assert %{"t_last" => _, "type" => "r"} = success_data
      assert [[1], [2], [3], [4], [5], [6], [7], [8], [9], [10]] == records
    end

    @tag :bolt_4_x
    @tag :bolt_5_x
    test "simple query with wrong extra parameters" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      query = "RETURN 1024 AS a, 2048 AS b"

      {:error, %Boltx.Error{code: :request_invalid}} =
        Client.run_statement(client, query, %{}, %{n: %{d: 4}})
    end
  end

  describe "Explicit Transaction" do
    @tag :core
    test "simple begin message" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)
      assert {:ok, _} = Client.send_begin(client, %{})
    end

    @tag :core
    test "simple commit message" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:ok, _} = Client.send_begin(client, %{})
      assert {:ok, _} = Client.send_commit(client)
    end

    @tag :bolt_1_x
    @tag :bolt_2_x
    test "simple commit message without starting a transaction in menor bolt 2" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:error, %Boltx.Error{code: :semantic_error}} = Client.send_commit(client)
    end

    @tag :bolt_3_x
    @tag :bolt_4_x
    @tag :bolt_5_x
    test "simple commit message without starting a transaction mayor 3" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:error, %Boltx.Error{code: :request_invalid}} = Client.send_commit(client)
    end

    @tag :core
    test "simple rollback message" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:ok, _} = Client.send_begin(client, %{})
      assert {:ok, _} = Client.send_rollback(client)
    end

    @tag :bolt_3_x
    @tag :bolt_4_x
    @tag :bolt_5_x
    test "simple rollback message without starting a transaction mayor 3" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:error, %Boltx.Error{code: :request_invalid}} = Client.send_rollback(client)
    end
  end

  describe "ack_failure message" do
    @tag :bolt_1_x
    @tag :bolt_2_x
    test "allows to recover from error with ack_failure" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:error, _} = Client.run_statement(client, "Invalid cypher", %{}, %{})
      assert {:ok, _} = Client.send_ack_failure(client)

      assert {:ok, _} = Client.run_statement(client, "RETURN 1 as num", %{}, %{})
    end

    @tag :bolt_1_x
    @tag :bolt_2_x
    test "returns proper error when misusing ack_failure and reset" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      {:error, %Boltx.Error{code: :request_invalid}} =
        Client.send_ack_failure(client)
    end
  end

  describe "reset message" do
    @tag :bolt_3_x
    @tag :bolt_4_x
    @tag :bolt_5_x
    test "ok send_reset" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:ok, _} = Client.run_statement(client, "RETURN 1 as num", %{}, %{})
      assert {:ok, _} = Client.send_reset(client)
    end

    @tag :bolt_3_x
    @tag :bolt_4_x
    @tag :bolt_5_x
    test "allows to recover from error with send_reset" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:error, _} = Client.run_statement(client, "Invalid cypher", %{}, %{})
      assert {:ok, _} = Client.send_reset(client)

      assert {:ok, _} = Client.run_statement(client, "RETURN 1 as num", %{}, %{})
    end
  end

  describe "goodbye message" do
    @tag :bolt_3_x
    @tag :bolt_4_x
    @tag :bolt_5_x
    test "goodbye/1" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert :ok = Client.send_goodbye(client)
    end
  end

  describe "discard message:" do
    @tag :core
    test "discard_all/2 (successful)" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      {:ok, _} = Client.send_run(client, "RETURN 1 as num", %{}, %{})

      assert {:ok, %{"t_last" => _, "type" => "r"}} = Client.send_discard(client, %{})
    end
  end

  describe "Logoff Message:" do
    @tag :bolt_version_5_1
    @tag :bolt_version_5_2
    @tag :bolt_version_5_3
    @tag :bolt_version_5_4
    test "send_logoff/1 (successful)" do
      assert {:ok, client} = Client.connect(@opts)
      Client.send_hello(client, @opts)
      Client.send_logon(client, @opts)

      assert {:ok, _} = Client.send_logoff(client)
      assert {:ok, _} = Client.send_logon(client, @opts)
    end
  end

  describe "Ping message:" do
    @tag :core
    test "send_ping/1 (successful)" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:ok, true} = Client.send_ping(client)
    end

    @tag :bolt_version_3_x
    @tag :bolt_version_4_x
    @tag :bolt_version_5_x
    test "send_ping/1 (failure)" do
      opts = @opts ++ [pool_size: 1]
      assert {:ok, client} = Client.connect(opts)
      {:ok, server_metadata} = handle_handshake(client, @opts)

      Client.run_statement(
        client,
        "CALL dbms.killConnection($connection_id)",
        %{connection_id: server_metadata["connection_id"]},
        %{}
      )

      assert {:error, :db_ping_failed} = Client.send_ping(client)
    end
  end
end
