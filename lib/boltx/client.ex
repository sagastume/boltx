defmodule Boltx.Client do
  @moduledoc false

  @handshake_bytes_identifier <<0x60, 0x60, 0xB0, 0x17>>
  @noop_chunk <<0x00, 0x00>>

  import Boltx.BoltProtocol.ServerResponse

  alias Boltx.BoltProtocol.Versions
  alias Boltx.Utils.Converters
  alias Boltx.BoltProtocol.MessageDecoder

  alias Boltx.BoltProtocol.Message.{
    HelloMessage,
    InitMessage,
    LogonMessage,
    RunMessage,
    PullMessage,
    BeginMessage,
    CommitMessage,
    RollbackMessage,
    AckFailureMessage,
    ResetMessage,
    GoodbyeMessage,
    DiscardMessage,
    LogoffMessage
  }

  defstruct [:sock, :bolt_version]

  defmodule Config do
    @moduledoc false

    @default_timeout 15_000

    defstruct [
      :hostname,
      :port,
      :scheme,
      :username,
      :password,
      :connect_timeout,
      :socket_options,
      :versions,
      :ssl?,
      :ssl_opts
    ]

    def new(opts) do
      {hostname, port} = get_hostname_and_port(opts)
      {username, password} = get_user_and_pass(opts)
      {scheme, ssl?, ssl_opts} = get_scheme_and_ssl_opts(opts)
      versions = get_versions(opts)

      %__MODULE__{
        hostname: hostname,
        port: port,
        scheme: scheme,
        username: username,
        password: password,
        connect_timeout: Keyword.get(opts, :connect_timeout, @default_timeout),
        socket_options:
          Keyword.merge([mode: :binary, packet: :raw, active: false], opts[:socket_options] || []),
        versions: versions,
        ssl?: ssl?,
        ssl_opts: ssl_opts
      }
    end

    defp get_scheme_and_ssl_opts(opts) do
      scheme = get_schema(opts)
      ssl_opts = Keyword.get(opts, :ssl_opts, [])

      {ssl, ssl_opts} =
        case scheme do
          "bolt" -> {false, ssl_opts}
          "neo4j" -> {false, ssl_opts}
          "neo4j+s" -> {true, Keyword.merge(ssl_opts, verify: :verify_none)}
          "bolt+s" -> {true, Keyword.merge(ssl_opts, verify: :verify_none)}
          "neo4j+ssc" -> {true, Keyword.merge(ssl_opts, verify: :verify_peer)}
          "bolt+ssc" -> {true, Keyword.merge(ssl_opts, verify: :verify_peer)}
          _ -> {true, ssl_opts}
        end

      {scheme, ssl, ssl_opts}
    end

    defp get_user_and_pass(opts) do
      basic_auth = Keyword.get(opts, :auth, [])

      username =
        System.get_env("BOLT_USER") || Keyword.get(basic_auth, :username, nil) ||
          raise(":username is missing")

      password = System.get_env("BOLT_PWD") || Keyword.get(basic_auth, :password)

      {username, password}
    end

    defp get_hostname_and_port(opts) do
      uri = Keyword.get(opts, :uri, nil) |> to_string() |> URI.parse()
      port_default = String.to_integer(System.get_env("BOLT_TCP_PORT") || "7687")

      hostname =
        uri.host || Keyword.get(opts, :hostname, nil) || System.get_env("BOLT_HOST") ||
          "localhost"

      port = uri.port || Keyword.get(opts, :port, port_default)
      {hostname, port}
    end

    defp get_schema(opts) do
      uri = Keyword.get(opts, :uri, nil) |> to_string() |> URI.parse()
      uri.scheme || Keyword.get(opts, :scheme, nil) || "bolt+s"
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
    client = %__MODULE__{sock: nil, bolt_version: nil}

    case maybe_connect_to_ssl(client, config) do
      {:ok, client} ->
        {:ok, client}

      other ->
        other
    end
  end

  defp maybe_connect_to_ssl(client, %{ssl?: false} = config) do
    %{
      hostname: hostname,
      port: port,
      socket_options: socket_options,
      connect_timeout: connect_timeout
    } = config

    case :gen_tcp.connect(String.to_charlist(hostname), port, socket_options, connect_timeout) do
      {:ok, sock} ->
        {:ok, %{client | sock: {:gen_tcp, sock}}}

      {:error, :timeout} ->
        {:error, Boltx.Error.wrap(__MODULE__, :timeout)}

      other ->
        other
    end
  end

  defp maybe_connect_to_ssl(client, %{ssl?: true} = config) do
    %{
      hostname: hostname,
      port: port,
      socket_options: socket_options,
      connect_timeout: connect_timeout,
      ssl_opts: ssl_opts
    } = config

    opts = Keyword.merge(ssl_opts, socket_options)

    case :ssl.connect(String.to_charlist(hostname), port, opts, connect_timeout) do
      {:ok, ssl_sock} ->
        {:ok, %{client | sock: {:ssl, ssl_sock}}}

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
    data =
      @handshake_bytes_identifier <>
        (config.versions
         |> Enum.sort(&>=/2)
         |> Enum.reduce(<<>>, fn version, acc -> acc <> Versions.to_bytes(version) end))

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

  def generic_decoder(_bolt_version, binary_messages) do
    messages = Enum.map(binary_messages, &MessageDecoder.decode(&1))
    response = hd(messages)

    case response do
      {:success, response} ->
        {:ok, response}

      {:failure, response} ->
        {:error,
         Boltx.Error.wrap(__MODULE__, %{code: response["code"], message: response["message"]})}
    end
  end

  def send_hello(client, fields) do
    payload = HelloMessage.encode(client.bolt_version, fields)

    with :ok <- send_packet(client, payload) do
      recv_packets(client, &__MODULE__.generic_decoder/2, :infinity)
    end
  end

  def send_logon(client, fields) do
    payload = LogonMessage.encode(client.bolt_version, fields)

    with :ok <- send_packet(client, payload) do
      recv_packets(client, &__MODULE__.generic_decoder/2, :infinity)
    end
  end

  def send_init(client, fields) do
    payload = InitMessage.encode(client.bolt_version, fields)

    with :ok <- send_packet(client, payload) do
      recv_packets(client, &__MODULE__.generic_decoder/2, :infinity)
    end
  end

  def send_run(client, query, parameters, extra_parameters) do
    payload = RunMessage.encode(client.bolt_version, query, parameters, extra_parameters)

    with :ok <- send_packet(client, payload) do
      recv_packets(client, &RunMessage.decode/2, :infinity)
    end
  end

  def send_pull(client, extra_parameters) do
    payload = PullMessage.encode(client.bolt_version, extra_parameters)

    with :ok <- send_packet(client, payload) do
      recv_packets(client, &PullMessage.decode/2, :infinity)
    end
  end

  def run_statement(client, query, parameters, extra_parameters) do
    with {:ok, result_run} <- send_run(client, query, parameters, extra_parameters),
         {:ok, result_pull} <- send_pull(client, extra_parameters) do
      {:ok, statement_result(result_run: result_run, result_pull: result_pull, query: query)}
    end
  end

  def run_statement(client, %Boltx.Query{} = query, parameters) do
    %Boltx.Query{statement: statement, extra: extra_parameters} = query

    run_statement(client, statement, parameters, extra_parameters)
  end

  def run_statement(client, %Boltx.Queries{} = queries, parameters) do
    %Boltx.Queries{statement: statement, extra: extra_parameters} = queries

    cypher_seps = ~r/;(.){0,1}\n/

    statements =
      statement
      |> String.split(cypher_seps, trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(String.length(&1) > 0))

    {:ok,
     Enum.reduce(statements, [], fn statement, acc ->
       case Boltx.Client.run_statement(client, statement, parameters, extra_parameters) do
         {:ok, result} ->
           [result | acc]

         _ ->
           acc
       end
     end)}
  end

  def send_begin(client, _extra_parameters)
      when is_float(client.bolt_version) and client.bolt_version <= 2.0 do
    case run_statement(client, "BEGIN", %{}, %{}) do
      {:ok, pull_result(success_data: success_data)} ->
        {:ok, success_data}

      other ->
        other
    end
  end

  def send_begin(client, extra_parameters) do
    payload = BeginMessage.encode(client.bolt_version, extra_parameters)

    with :ok <- send_packet(client, payload) do
      recv_packets(client, &__MODULE__.generic_decoder/2, :infinity)
    end
  end

  def send_commit(client) when is_float(client.bolt_version) and client.bolt_version <= 2.0 do
    case run_statement(client, "COMMIT", %{}, %{}) do
      {:ok, pull_result(success_data: success_data)} ->
        {:ok, success_data}

      other ->
        other
    end
  end

  def send_commit(client) do
    payload = CommitMessage.encode(client.bolt_version)

    with :ok <- send_packet(client, payload) do
      recv_packets(client, &__MODULE__.generic_decoder/2, :infinity)
    end
  end

  def send_rollback(client)
      when is_float(client.bolt_version) and client.bolt_version <= 2.0 do
    case run_statement(client, "ROLLBACK", %{}, %{}) do
      {:ok, pull_result(success_data: success_data)} ->
        {:ok, success_data}

      other ->
        other
    end
  end

  def send_rollback(client) do
    payload = RollbackMessage.encode(client.bolt_version)

    with :ok <- send_packet(client, payload) do
      recv_packets(client, &__MODULE__.generic_decoder/2, :infinity)
    end
  end

  def send_ack_failure(client) do
    payload = AckFailureMessage.encode(client.bolt_version)

    with :ok <- send_packet(client, payload) do
      recv_packets(client, &__MODULE__.generic_decoder/2, :infinity)
    end
  end

  def send_reset(client) do
    payload = ResetMessage.encode(client.bolt_version)

    with :ok <- send_packet(client, payload) do
      recv_packets(client, &__MODULE__.generic_decoder/2, :infinity)
    end
  end

  def send_discard(client, extra_parameters) do
    payload = DiscardMessage.encode(client.bolt_version, extra_parameters)

    with :ok <- send_packet(client, payload) do
      recv_packets(client, &DiscardMessage.decode/2, :infinity)
    end
  end

  def send_goodbye(client) do
    payload = GoodbyeMessage.encode(client.bolt_version)

    with {:error, :closed} <- send_packet(client, payload) do
      try do
        disconnect(client)
        :ok
      rescue
        ArgumentError ->
          {:error,
           Boltx.Error.wrap(__MODULE__, %{
             code: :failed_port_close,
             message: "Error closing port with goodbye message"
           })}
      end
    end
  end

  def send_logoff(client) do
    payload = LogoffMessage.encode(client.bolt_version)

    with :ok <- send_packet(client, payload) do
      recv_packets(client, &__MODULE__.generic_decoder/2, :infinity)
    end
  end

  def send_ping(client) do
    case run_statement(client, "RETURN true as success", %{}, %{}) do
      {:ok, statement_result(result_pull: pull_result(records: [[true]]))} ->
        {:ok, true}

      _ ->
        {:error, :db_ping_failed}
    end
  end

  defp decode_version(<<0, 0, minor::unsigned-integer, major::unsigned-integer>>)
       when is_integer(major) and is_integer(minor) do
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
        case concatenate_chunks(response, chunks) do
          {:complete_chunks, binary_messages} ->
            decode_messages(client.bolt_version, binary_messages, decoder)

          {:remaining_chunks, binary_message} ->
            recv_packets(client, decoder, timeout, binary_message)
        end

      {:error, :timeout} ->
        {:error, Boltx.Error.wrap(__MODULE__, :timeout)}

      {:error, _} = error ->
        error
    end
  end

  defp concatenate_chunks(response, chunks) do
    case response do
      @noop_chunk ->
        {:remaining_chunks, chunks}

      <<_::binary-size(byte_size(response) - 2), 0, 0>> ->
        {:complete_chunks, chunks <> response}

      <<_::binary>> ->
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
