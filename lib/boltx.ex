defmodule Boltx do
  @moduledoc """
  Bolt driver for Elixir.
  """

  @type conn() :: DBConnection.conn()

  @typedoc """
  The basic authentication scheme relies on traditional username and password

  * `:username` - Username (default: `BOLT_USER` env variable)

  * `:password` - Password (default: `BOLT_PWD` env variable, then `nil`)
  """
  @type basic_auth() ::
          {:username, String.t()}
          | {:password, String.t() | nil}

  @type start_option() ::
          {:uri, String.t()}
          | {:hostname, String.t()}
          | {:port, :inet.port_number()}
          | {:scheme, :inet.port_number()}
          | {:versions, list(float())}
          | {:auth, basic_auth()}
          | {:user_agent, String.t()}
          | {:notifications_minimum_severity, String.t()}
          | {:notifications_disabled_categories, list(String.t())}
          | {:ssl, boolean()}
          | {:ssl_opts, [:ssl.tls_client_option()]}
          | {:connect_timeout, timeout()}
          | {:socket_options, [:gen_tcp.connect_option()]}
          | DBConnection.start_option()

  @type option :: %{
          bookmarks: list(),
          mode: String.t(),
          db: String.t() | nil,
          tx_metadata: map() | nil
        }

  alias Boltx.{Types}

  @doc """
  Starts the connection process and connects to a Bolt/Neo4j server.

  ## Options

  * `:uri` - Connection URI. The uri configuration takes priority over the hostname, port, and scheme options.
   URI has the form: `<SCHEME>://<HOST>[:<PORT>[?policy=<POLICY-NAME>]]`

  * `:hostname` - Server hostname (default: `BOLT_HOST` env variable, then `"localhost"`)

  * `:port` - Server port (default: `BOLT_TCP_PORT` env variable, then `7687`)

  * `:scheme` - Is one among neo4j, neo4j+s, neo4j+ssc, bolt, bolt+s, bolt+ssc (default: bolt+s).

  * `:versions` - List of bolt versions you want to be negotiated with the server.

  * `:auth` - The basic authentication scheme

  * `:user_agent` - Optionally override the default user agent name. (Default: 'boltx/<version>')

  * `:notifications_minimum_severity` - Set the minimum severity for notifications the server
   should send to the client. Disabling severities allows the server to skip analysis for those,
  which can speed up query execution. (default: nil) _New in neo4j v5.7 and Bolt v5.2_

  * `:notifications_disabled_categories` - Set categories of notifications the server should not
   send to the client. Disabling categories allows the server to skip analysis for those, which
  can speed up query execution. (default: nil) _New in neo4j v5.7 and Bolt v5.2_

  * `:connect_timeout` - Socket connect timeout in milliseconds (default:
      `15_000`)

  * `:ssl` - Set to `true` if SSL should be used (default: `true`)

  * `:ssl_opts` - A list of SSL options, see `:ssl.connect/2` (default: `[verify: :verify_none]`)

  The given options are passed down to DBConnection, some of the most commonly used ones are
   documented below:

  * `:after_connect` - A function to run after the connection has been established, either a
      1-arity fun, a `{module, function, args}` tuple, or `nil` (default: `nil`)

  * `:pool` - The pool module to use, defaults to built-in pool provided by DBconnection

  * `:pool_size` - The size of the pool
  """
  @spec start_link([start_option()]) :: {:ok, pid()} | {:error, Boltx.Error.t()}
  def start_link(options) do
    DBConnection.start_link(Boltx.Connection, options)
  end

  @doc """
  Returns a supervisor child specification for a DBConnection pool.
  """
  @spec child_spec([start_option()]) :: :supervisor.child_spec()
  def child_spec(options) do
    DBConnection.child_spec(Boltx.Connection, options)
  end

  @doc """
  Executes a single query and returns the result.

  ## Examples

  ```elixir
  {:ok, result} = Boltx.query(conn, "MATCH (n) RETURN n LIMIT 1")

  {:ok, people} = Boltx.query(conn, "MATCH (n:PERSON) RETURN n", %{}, [db: "mydb"])
  ```
  """
  def query(conn, statement, params \\ %{}, opts \\ []) do
    formatted_params =
      params
      |> Enum.map(&format_param/1)
      |> Enum.map(fn {k, {:ok, value}} -> {k, value} end)
      |> Map.new()

    extra =
      opts
      |> Keyword.take([:bookmarks, :mode, :db, :tx_metadata])
      # Convert to map
      |> Enum.into(%{})

    query = %Boltx.Query{statement: statement, extra: extra}

    do_query(conn, query, formatted_params, opts)
  end

  @doc """
  Executes a single query and returns the result.

  ## Examples

  ```elixir
  result = Boltx.query!(conn, "MATCH (n) RETURN n LIMIT 1")

  people = Boltx.query!(conn, "MATCH (n:PERSON) RETURN n", %{}, [db: "mydb"])
  ```
  """
  def query!(conn, statement, params \\ %{}, opts \\ []) do
    case query(conn, statement, params, opts) do
      {:ok, result} -> result
      {:error, exception} -> raise exception
    end
  end

  def query_many(conn, statement, params \\ %{}, opts \\ []) do
    formatted_params =
      params
      |> Enum.map(&format_param/1)
      |> Enum.map(fn {k, {:ok, value}} -> {k, value} end)
      |> Map.new()

    queries = %Boltx.Queries{statement: statement}
    do_query(conn, queries, formatted_params, opts)
  end

  def query_many!(conn, statement, params \\ %{}, opts \\ []) do
    case query_many(conn, statement, params, opts) do
      {:ok, result} -> result
      {:error, exception} -> raise exception
    end
  end

  @spec transaction(conn, (DBConnection.t() -> result), [DBConnection.option()], option) ::
          {:ok, result} | {:error, any}
        when result: var
  def transaction(conn, fun, opts \\ [], extra_parameters \\ %{}) do
    DBConnection.transaction(conn, fun, opts ++ [extra_parameters: extra_parameters])
  end

  @spec rollback(DBConnection.t(), any()) :: no_return()
  defdelegate rollback(conn, reason), to: DBConnection

  defp do_query(conn, query, params, options) do
    case DBConnection.prepare_execute(conn, query, params, options) do
      {:ok, _query, result} -> {:ok, result}
      {:error, _} = error -> error
    end
  end

  defp format_param({name, %Types.Duration{} = duration}),
    do: {name, Types.Duration.format_param(duration)}

  defp format_param({name, %Types.Point{} = point}), do: {name, Types.Point.format_param(point)}

  defp format_param({name, value}), do: {name, {:ok, value}}
end
