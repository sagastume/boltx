defmodule Boltx.Client do
  @handshake_bytes_identifier <<0x60, 0x60, 0xB0, 0x17>>
  @noop_chunk <<0x00, 0x00>>

  import Boltx.BoltProtocol.ServerResponse

  alias Boltx.BoltProtocol.Versions
  alias Boltx.Utils.Converters
  alias Boltx.BoltProtocol.Message.{
    HelloMessage,
    InitMessage,
    LogonMessage,
    RunMessage,
    PullMessage,
    BeginMessage,
    CommitMessage,
    RollbackMessage
  }

  defstruct [:sock, :connection_id, :bolt_version]

  defmodule Config do
    @moduledoc false

    @default_timeout 5_000

    defstruct [
      :address,
      :port,
      :username,
      :password,
      :connect_timeout,
      :socket_options,
      :versions
    ]

    def new(opts) do
      address = Keyword.get(opts, :address, System.get_env("BOLT_HOST"))
      address = String.to_charlist(address || "localhost")
      versions = get_versions(opts)

      default_port = String.to_integer(System.get_env("BOLT_TCP_PORT") || "7687")
      port = Keyword.get(opts, :port, default_port)

      %__MODULE__{
        address: address,
        port: port,
        username: Keyword.get(opts, :username, System.get_env("USER")) || raise(":username is missing"),
        password: Keyword.get(opts, :password),
        connect_timeout: Keyword.get(opts, :connect_timeout, @default_timeout),
        socket_options:
          Keyword.merge([mode: :binary, packet: :raw, active: false], opts[:socket_options] || []),
        versions: versions
      }
    end

    def get_versions(opts) do
      versions =
        case Keyword.get(opts, :versions) do
          nil ->
            case System.get_env("BOLT_VERSIONS") do
              nil ->
                Versions.latest_versions()
              env_versions ->
                  env_versions
                  |> String.split(",")
                  |> Enum.map(&Converters.to_float/1)
            end
          ops_versions ->
            ops_versions
        end

      ((versions |> Enum.into([])) ++ [0, 0, 0]) |> Enum.take(4) |> Enum.sort(&>=/2)
    end
  end

  def connect(%Config{} = config) do
    with {:ok, client} <- do_connect(config) do
      handshake(client, config)
    end
  end

  def connect(opts) when is_list(opts) do
    connect(Config.new(opts))
  end

  def do_connect(config) do
    %{
      address: address,
      port: port,
      socket_options: socket_options,
      connect_timeout: connect_timeout
    } = config

    buffer? = Keyword.has_key?(socket_options, :buffer)
    client = %__MODULE__{connection_id: nil, sock: nil, bolt_version: nil}
    case :gen_tcp.connect(address, port, socket_options, connect_timeout) do
      {:ok, sock} when buffer? ->
        {:ok, %{client | sock: {:gen_tcp, sock}}}

      {:ok, sock} ->
        {:ok, [sndbuf: sndbuf, recbuf: recbuf, buffer: buffer]} =
          :inet.getopts(sock, [:sndbuf, :recbuf, :buffer])

        buffer = buffer |> max(sndbuf) |> max(recbuf)
        :ok = :inet.setopts(sock, buffer: buffer)
        {:ok, %{client | sock: {:gen_tcp, sock}}}

      {:error, :timeout} ->
        {:error, Boltx.Error.wrap(__MODULE__, :timeout)}

      other ->
        other
    end
  end

  defp handshake(client, config) do
    case do_handshake(client, config) do
      {:ok, client} ->
        {:ok, client}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_handshake(client, config) do
    data = @handshake_bytes_identifier <> (config.versions |>  Enum.sort(&>=/2) |> Enum.reduce(<<>>, fn version, acc -> acc <> Versions.to_bytes(version) end))
    with :ok <- send_packet(client, data),
    encode_version <- recv_packets(client, config.connect_timeout),
    version <- decode_version(encode_version) do
      case version do
        0.0 -> {:error, Boltx.Error.wrap(__MODULE__, :version_negotiation_error)}
        _ -> {:ok, %{client | bolt_version: version}}
      end
    else
      _ ->
        {:error, "Could not negotiate the version"}
    end
  end

  def message_hello(client, fields) do
    payload = HelloMessage.encode(client.bolt_version, fields)
    with :ok <- send_packet(client, payload) do
      recv_packets(client, &HelloMessage.decode/2, :infinity)
    end
  end

  def message_logon(client, fields) do
    payload = LogonMessage.encode(client.bolt_version, fields)
    with :ok <- send_packet(client, payload) do
      recv_packets(client, &LogonMessage.decode/2, :infinity)
    end
  end

  def message_init(client, fields) do
    payload = InitMessage.encode(client.bolt_version, fields)
    with :ok <- send_packet(client, payload) do
      recv_packets(client, &InitMessage.decode/2, :infinity)
    end
  end

  def message_run(client, query, parameters, extra_parameters) do
    payload = RunMessage.encode(client.bolt_version, query, parameters, extra_parameters)
    with :ok <- send_packet(client, payload) do
      recv_packets(client, &RunMessage.decode/2, :infinity)
    end
  end

  def message_pull(client, extra_parameters) do
    payload = PullMessage.encode(client.bolt_version, extra_parameters)
    with :ok <- send_packet(client, payload) do
      recv_packets(client, &PullMessage.decode/2, :infinity)
    end
  end

  def run_statement(client, query, parameters, extra_parameters) do
    with {:ok, result_run} <- message_run(client, query, parameters, extra_parameters),
         {:ok, result_pull} <- message_pull(client, extra_parameters) do
      {:ok, statement_result(result_run: result_run, result_pull: result_pull, query: query)}
    end
  end

  def message_begin(client, _extra_parameters) when is_float(client.bolt_version) and client.bolt_version <= 2.0 do
    case run_statement(client, "BEGIN", %{}, %{}) do
      {:ok, pull_result(success_data: success_data )} ->
        {:ok, success_data}
      other ->
        other
    end
  end

  def message_begin(client, extra_parameters) do
    payload = BeginMessage.encode(client.bolt_version, extra_parameters)
    with :ok <- send_packet(client, payload) do
      recv_packets(client, &BeginMessage.decode/2, :infinity)
    end
  end

  def message_commit(client) when is_float(client.bolt_version) and client.bolt_version <= 2.0 do
    case run_statement(client, "COMMIT", %{}, %{}) do
      {:ok, pull_result(success_data: success_data )} ->
        {:ok, success_data}
      other ->
        other
    end
  end

  def message_commit(client) do
    payload = CommitMessage.encode(client.bolt_version)
    with :ok <- send_packet(client, payload) do
      recv_packets(client, &CommitMessage.decode/2, :infinity)
    end
  end

  def message_rollback(client) when is_float(client.bolt_version) and client.bolt_version <= 2.0 do
    case run_statement(client, "ROLLBACK", %{}, %{}) do
      {:ok, pull_result(success_data: success_data )} ->
        {:ok, success_data}
      other ->
        other
    end
  end

  def message_rollback(client) do
    payload = RollbackMessage.encode(client.bolt_version)
    with :ok <- send_packet(client, payload) do
      recv_packets(client, &RollbackMessage.decode/2, :infinity)
    end
  end

  defp decode_version(<<0, 0, minor::unsigned-integer, major::unsigned-integer>>) when is_integer(major) and is_integer(minor) do
    Float.round(major + minor / 10.0, 1)
  end

  def send_packet(client, payload) do
    send_data(client, payload)
  end

  def send_data(%{sock: {sock_mod, sock}}, data) do
    sock_mod.send(sock, data)
  end

  def recv_packets(client, timeout) do
    case recv_data(client, timeout) do
      {:ok, response} ->
        response
      {:error, :timeout} ->
          {:error, Boltx.Error.wrap(__MODULE__, :timeout)}
      {:error, _} = error ->
        error
    end
  end

  def recv_packets(client, decoder, timeout) do
    recv_packets(client, decoder, timeout, <<>>)
  end

  defp recv_packets(client, decoder, timeout, chunks) do
    case recv_data(client, timeout) do
      {:ok, response} ->
        case concatenateChunks(response, chunks) do
          {:complete_chunks, binary_messages} ->
            decode_messages(client.bolt_version, binary_messages, decoder)
          {:remaining_chunks, binary_message} -> recv_packets(client, decoder, timeout, binary_message)
        end
      {:error, :timeout} ->
        {:error, Boltx.Error.wrap(__MODULE__, :timeout)}
      {:error, _} = error ->
        error
    end
  end

  defp concatenateChunks(response, chunks) do
    case response do
      @noop_chunk ->
        {:remaining_chunks, chunks}
      <<_::binary-size(byte_size(response)-2), 0,0>> ->
        {:complete_chunks, chunks <> response}
      << _::binary>> ->
        {:remaining_chunks, chunks <> response}
    end
  end

  def decode_messages(bolt_version, binary_messages, decoder) do
    messages = split_message(binary_messages, [])
    decoder.(bolt_version, messages)
  end

  defp split_message(<<size::16, data::binary>>, acc) do
    <<message::binary-size(size + byte_size(@noop_chunk)), remaining::binary>> = data
    split_message(remaining, [message | acc])
  end

  defp split_message(<<>>, acc) do
    acc
  end

  def recv_data(%{sock: {sock_mod, sock}}, timeout) do
    sock_mod.recv(sock, 0, timeout)
  end

  def disconnect(client) do
    {sock_mod, sock} = client.sock
    sock_mod.close(sock)
    :ok
  end

  def checkin(client) do
    {sock_mod, sock} = client.sock
    case sock_mod.setopts(sock, active: :once) do
      :ok -> :ok
      other -> other
    end
  end
end
