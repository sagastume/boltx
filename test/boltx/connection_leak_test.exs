defmodule Boltx.ConnectionLeakTest do
  # async: false — inspects process-owned ports to detect socket leaks.
  use ExUnit.Case, async: false

  alias Boltx.Connection

  @moduletag :core

  @handshake_magic <<0x60, 0x60, 0xB0, 0x17>>

  describe "connect/1 socket leak on failed init" do
    test "closes the socket when the handshake succeeds but HELLO/init fails" do
      {port, listener} = start_failing_bolt_server()
      on_exit(fn -> :gen_tcp.close(listener) end)

      opts = [
        hostname: "127.0.0.1",
        port: port,
        scheme: "bolt",
        ssl: false,
        auth: [username: "neo4j", password: "irrelevant"],
        connect_timeout: 2000
      ]

      # The failing server reproduces the target path: TCP accept + version
      # negotiation succeed (so Client.connect/1 returns {:ok, client}), then the
      # server drops the connection on HELLO so do_init/2 fails.
      assert {:error, _reason} = Connection.connect(opts)

      # Warm up one connect so any lazy per-process port allocation is already
      # counted before we measure the baseline.
      before = count_owned_ports()

      n = 25

      for _ <- 1..n do
        assert {:error, _reason} = Connection.connect(opts)
      end

      after_count = count_owned_ports()
      delta = after_count - before

      assert delta <= 1,
             "socket leak: owned port count grew by #{delta} across #{n} failed connects " <>
               "(before=#{before}, after=#{after_count}); each failed init leaked a socket"
    end
  end

  # Count the ports (TCP sockets are ports on the default inet backend) whose
  # controlling/connected process is this test process. The fake server's listen
  # and accept sockets are owned by the server process, so they are excluded;
  # only client sockets opened by Connection.connect/1 (which runs synchronously
  # in this process) are counted.
  defp count_owned_ports do
    me = self()

    Enum.count(Port.list(), fn port ->
      match?({:connected, ^me}, Port.info(port, :connected))
    end)
  end

  # A minimal Bolt server that completes the version handshake (selecting bolt
  # 5.4) and then closes the connection instead of answering HELLO, forcing
  # do_init/2 to fail after Client.connect/1 has already opened the socket.
  defp start_failing_bolt_server do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true])

    {:ok, port} = :inet.port(listener)
    spawn_link(fn -> accept_loop(listener) end)
    {port, listener}
  end

  defp accept_loop(listener) do
    case :gen_tcp.accept(listener) do
      {:ok, sock} ->
        serve_and_fail(sock)
        accept_loop(listener)

      {:error, :closed} ->
        :ok
    end
  end

  defp serve_and_fail(sock) do
    case :gen_tcp.recv(sock, 20, 2000) do
      {:ok, <<@handshake_magic, _offered_versions::binary-size(16)>>} ->
        # Select bolt 5.4 (decoded as major 5, minor 4) so handshake succeeds.
        :gen_tcp.send(sock, <<0, 0, 4, 5>>)
        # Consume whatever HELLO bytes arrive, then drop the connection so the
        # client's HELLO recv fails and do_init/2 returns an error.
        _ = :gen_tcp.recv(sock, 0, 2000)
        :gen_tcp.close(sock)

      _ ->
        :gen_tcp.close(sock)
    end
  end
end
