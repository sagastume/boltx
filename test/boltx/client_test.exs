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
        Client.message_hello(client, opts)
        Client.message_logon(client, opts)

      version when version >= 3.0 ->
        Client.message_hello(client, opts)

      version when version <= 2.0 ->
        Client.message_init(client, opts)
    end
  end

  describe "connect" do
    @tag bolt_version: "5.3"
    test "multiple versions specified" do
      opts = [versions: [5.3, 4, 3]] ++ @opts
      assert {:ok, client} = Client.connect(opts)
      assert 5.3 == client.bolt_version
    end

    @tag bolt_version: "5.3"
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

    @tag bolt_version: "1.0"
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
      assert {:ok, _} = Client.message_begin(client, %{})
    end

    @tag :core
    test "simple commit message" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:ok, _} = Client.message_begin(client, %{})
      assert {:ok, _} = Client.message_commit(client)
    end

    @tag :bolt_1_x
    @tag :bolt_2_x
    test "simple commit message without starting a transaction in menor bolt 2" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:error, %Boltx.Error{code: :semantic_error}} = Client.message_commit(client)
    end

    @tag :bolt_3_x
    @tag :bolt_4_x
    @tag :bolt_5_x
    test "simple commit message without starting a transaction mayor 3" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:error, %Boltx.Error{code: :request_invalid}} = Client.message_commit(client)
    end

    @tag :core
    test "simple rollback message" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:ok, _} = Client.message_begin(client, %{})
      assert {:ok, _} = Client.message_rollback(client)
    end

    @tag :bolt_3_x
    @tag :bolt_4_x
    @tag :bolt_5_x
    test "simple rollback message without starting a transaction mayor 3" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:error, %Boltx.Error{code: :request_invalid}} = Client.message_rollback(client)
    end
  end

  describe "ack_failure message" do
    @tag :bolt_1_x
    @tag :bolt_2_x
    test "allows to recover from error with ack_failure" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:error, _} = Client.run_statement(client, "Invalid cypher", %{}, %{})
      assert {:ok, _} = Client.message_ack_failure(client)

      assert {:ok, _} = Client.run_statement(client, "RETURN 1 as num", %{}, %{})
    end

    @tag :bolt_1_x
    @tag :bolt_2_x
    test "returns proper error when misusing ack_failure and reset" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      {:error, %Boltx.Error{code: :request_invalid}} =
        Client.message_ack_failure(client)
    end
  end

  describe "reset message" do
    @tag :bolt_3_x
    @tag :bolt_4_x
    @tag :bolt_5_x
    test "ok message_reset" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:ok, _} = Client.run_statement(client, "RETURN 1 as num", %{}, %{})
      assert {:ok, _} = Client.message_reset(client)
    end

    @tag :bolt_3_x
    @tag :bolt_4_x
    @tag :bolt_5_x
    test "allows to recover from error with message_reset" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      assert {:error, _} = Client.run_statement(client, "Invalid cypher", %{}, %{})
      assert {:ok, _} = Client.message_reset(client)

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

      assert :ok = Client.message_goodbye(client)
    end
  end

  describe "discard message:" do
    @tag :core
    test "discard_all/2 (successful)" do
      assert {:ok, client} = Client.connect(@opts)
      handle_handshake(client, @opts)

      {:ok, _} = Client.message_run(client, "RETURN 1 as num", %{}, %{})

      assert {:ok, %{"t_last" => _, "type" => "r"}} = Client.message_discard(client, %{})
    end
  end
end
