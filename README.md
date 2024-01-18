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
| Multi tenancy         | NO           |
| Stream capabilities   | NO           |
| Routing               | NO           |

## Usage

Add :boltx to your dependencies:

```elixir
def deps() do
  [
    {:boltx, "~> 0.0.4"}
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
iex> Boltx.query!(Boltx, "return 1 as n") |> Boltx.Response.first()
%{"n" => 1}
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


## Bolt Protocol message

| Message       | Bolt Version                            | Implemented |
| ------------- | --------------------------------------- | ----------- |
| INIT          | V1, V2                                  | YES         |
| HELLO         | V3, V4.x, v5.1, v5.2, v5.3, v5.4        | YES         |
| LOGON         | V3, V4.x, v5.1, v5.2, v5.3, v5.4        | YES         |
| RUN           | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4| YES         |
| PULL          | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4| YES         |
| BEGIN         | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4| YES         |
| COMMIT        | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4| YES         |
| ROLLBACK      | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4| YES         |
| LOGOFF        | V3, V4.x, v5.1, v5.2, v5.3, v5.4        | YES         |
| TELEMETRY     | V5.4                                    | NO          |
| GOODBYE       | V3, V4.x, v5.1, v5.2, v5.3, v5.4        | YES         |
| RESET         | V3, V4.x, v5.1, v5.2, v5.3, v5.4        | YES         |
| DISCARD       | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4| YES         |
| ROUTE         | V4.x, v5.1, v5.2, v5.3, v5.4            | NO          |
| ACK_FAILURE   | V1, V2                                  | YES         |

