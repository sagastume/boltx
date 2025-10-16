# Boltx

`Boltx` is an Elixir driver for [Neo4j](https://neo4j.com/developer/graph-database/)/Bolt Protocol.

- Supports Neo4j versions: 3.0.x/3.1.x/3.2.x/3.4.x/3.5.x/4.x/5.9 -5.13.0
- Supports Bolt version: 1.0/2.0/3.0/4.x/5.0/5.1/5.2/5.3/5.4
- Supports transactions, prepared queries, streaming, pooling and more via DBConnection
- Automatic decoding and encoding of Elixir values

Documentation: [https://hexdocs.pm/boltx](https://hexdocs.pm/boltx)

## Features

| Feature               | Implemented |
| --------------------- | ------------ |
| Querys                | YES          |
| Transactions          | YES          |
| Stream capabilities   | YES          |
| Routing               | NO           |

## Usage

Add :boltx to your dependencies:

```elixir
def deps() do
  [
    {:boltx, "~> 0.0.6"}
  ]
end
```

Using the latest version.

```elixir

opts = [
    hostname: "127.0.0.1",
    auth: [username: "neo4j", password: ""],
    user_agent: "boltxTest/1",
    pool_size: 15,
    max_overflow: 3,
    prefix: :default
]

iex> {:ok, conn} = Boltx.start_link(opts)
{:ok, #PID<0.237.0>}

iex> Boltx.query!(conn, "return 1 as n") |> Boltx.Response.first()
%{"n" => 1}

# Commit is performed automatically if everythings went fine
Boltx.transaction(conn, fn conn ->
  result = Boltx.query!(conn, "CREATE (m:Movie {title: "Matrix"}) RETURN m")
end)

```

### Set it up in an app

Add the configuration to the corresponding files for each environment or to your config/config.ex.
> #### Name of process
>
> The process name must be defined in your configuration


```elixir
import Config

config :boltx, Bolt,
  uri: "bolt://localhost:7687",
  auth: [username: "neo4j", password: "password"],
  user_agent: "boltxTest/1",
  pool_size: 15,
  max_overflow: 3,
  prefix: :default,
  name: Bolt
```

Add Boltx to the application's main monitoring tree and let OTP manage it.

```elixir
# lib/n4_d/application.ex

defmodule N4D.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      %{
        id: Boltx,
        start: {Boltx, :start_link, [Application.get_env(:boltx, Bolt)] },
      }
    ]

    opts = [strategy: :one_for_one, name: N4D.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```
Or

```elixir
children = [
  {Boltx, Application.get_env(:boltx, Bolt)}
]
```
Now you can run query with the name you set

```elixir
iex> Boltx.query!(Bolt, "return 1 as n") |> Boltx.Response.first()
%{"n" => 1}
```

### Streaming Large Result Sets

Boltx supports memory-efficient lazy streaming of large result sets using Elixir's `Stream` module. This allows you to process millions of records without loading them all into memory at once.

#### Basic Streaming

Stream results using `Response.stream/1`:

```elixir
# Query returns 1 million records
response = Boltx.query!(conn, "UNWIND range(1, 1000000) AS n RETURN n, n * 2 AS doubled")

# Process results lazily - only loads records as needed
response
|> Boltx.Response.stream()
|> Stream.filter(fn record -> rem(record["n"], 1000) == 0 end)
|> Stream.map(fn record -> record["doubled"] end)
|> Enum.take(10)
# => [2000, 4000, 6000, 8000, 10000, 12000, 14000, 16000, 18000, 20000]
```

#### Early Termination

Stop processing as soon as you find what you need:

```elixir
response = Boltx.query!(conn, "MATCH (p:Person) RETURN p.name, p.email")

# Find first matching record without processing everything
first_admin =
  response
  |> Boltx.Response.stream()
  |> Enum.find(fn record -> String.contains?(record["email"], "@admin.com") end)
```

#### Processing in Chunks

Process large datasets in batches:

```elixir
response = Boltx.query!(conn, "MATCH (n:Node) RETURN n")

# Process 500 records at a time
response
|> Boltx.Response.stream()
|> Stream.chunk_every(500)
|> Enum.each(fn chunk ->
  # Bulk insert into another system, send notifications, etc.
  MyApp.bulk_process(chunk)
end)
```

#### Aggregations and Reductions

Compute statistics without loading all data:

```elixir
response = Boltx.query!(conn, "MATCH (t:Transaction) RETURN t.amount")

# Calculate sum without loading all transactions into memory
total =
  response
  |> Boltx.Response.stream()
  |> Stream.map(fn record -> record["amount"] end)
  |> Enum.sum()
```

#### Server-Side Batch Pulling (Advanced)

For queries that haven't fully fetched results yet, use `Response.stream_with_client/2` to pull records in batches from the server:

```elixir
# For low-level client usage
{:ok, client} = Boltx.Client.connect(opts)
{:ok, result_run} = Boltx.Client.send_run(client, "UNWIND range(1, 1000000) AS n RETURN n", %{}, %{})

response = %Boltx.Response{
  fields: Map.get(result_run, "fields", []),
  records: [],
  results: []
}

# Stream with server-side pulling (fetch_size controls batch size)
response
|> Boltx.Response.stream_with_client(client, fetch_size: 1000)
|> Enum.take(5000)
# Only pulls 5-6 batches from server, not all 1 million records
```

### URI schemes

By default the scheme is `bolt+s`

| URI        | Description                                | TLSOptions              |
|------------|--------------------------------------------|-------------------------|
| neo4j      | Unsecured                                  | []                      |
| neo4j+s    | Secured with full certificate              | [verify: :verify_none]  |
| neo4j+ssc  | Secured with self-signed certificate       | [verify: :verify_peer]  |
| bolt       | Unsecured                                  | []                      |
| bolt+s     | Secured with full certificate              | [verify: :verify_none]  |
| bolt+ssc   | Secured with self-signed certificate       | [verify: :verify_peer]  |

## Contributing

### Getting Started

Neo4j uses the Bolt protocol for communication and query execution. You can find the official documentation for Bolt here: [Bolt Documentation](https://neo4j.com/docs/bolt/current).

It is crucial to grasp various concepts before getting started, with the most important ones being:

- [PackStream](https://neo4j.com/docs/bolt/current/packstream/): The syntax layer for the Bolt messaging protocol.
- [Bolt Protocol](https://neo4j.com/docs/bolt/current/bolt/): The application protocol for database queries via a database query language.
  - Bolt Protocol handshake specification
  - Bolt Protocol message specification
  - Structure Semantics

It is advisable to use the specific terminology from the official documentation and official drivers to ensure consistency with this implementation.

### Test

As certain versions of Bolt may be compatible with specific functionalities while others can undergo significant changes, tags are employed to facilitate version-specific testing. Some of these tags include:

- `:core` (Included in all executions).
- `:bolt_version_{{specific version}}` (Tag to run the test on a specific version, for example, for 5.2: `:bolt_version_5_2`, for version 1: `:bolt_version_1_0)`.
- `bolt_{major version}_x`  (Tag to run on all minor versions of a major version, for example, for 5: `:bolt_5_x`, for all minor versions of 4:: `:bolt_4_x`).
- `:last_version` (Tag to run the test only on the latest version).

By default, all tags are disabled except the `:core` tag. To enable the tags, it is necessary to configure the following environment variables:

- `BOLT_VERSIONS`: This variable is used for Bolt version configuration but is also useful for testing. You can specify a version, for example, BOLT_VERSIONS="1.0".
- `BOLT_TCP_PORT`:  You can configure the port with the environment variable (BOLT_TCP_PORT=7688).

#### Help script
To simplify test execution, the test-runner.sh script is available. You can find the corresponding documentation here: [Help script](scripts/README.md)
