# Boltx

`Boltx` is a derivative of Bolt_Sips currently in development. Is an Elixir driver for [Neo4j](https://neo4j.com/developer/graph-database/), providing many useful features:
- using the Bolt protocol, the Elixir implementation - the Neo4j's newest network protocol, designed for high-performance; latest Bolt versions, are supported.
- Supports Neo4j versions: 3.0.x/3.1.x/3.2.x/3.4.x/3.5.x/4.0.x/4.1.x/4.2.x/5.12.0, 5.13.0

## Features

Currently, the focus is on refactoring Bolt Sips to enhance the way Bolt messages are implemented, making it easier to implement new versions of Bolt in the future.

| Feature               | Implemented |
| --------------------- | ------------ |
| Querys                | YES          |
| Transactions          | NO           |
| Multi tenancy         | NO           |
| Stream capabilities   | NO           |
| Routing               | NO           |

### Basic usage
```elixir

opts = [
    address: "127.0.0.1",
    auth: [username: "neo4j", password: ""],
    bolt_agent: [product: "boltxTest/1"],
    pool_size: 15,
    max_overflow: 3,
    prefix: :default
]

iex> {:ok, conn} = Boltx.start_link(@opts)
{:ok, #PID<0.237.0>}

iex> Boltx.query!(conn, "return 1 as n") |>
...> Boltx.Response.first()
%{"n" => 1}
```

## Implemented messages

| Message       | Bolt Version                            |
| ------------- | --------------------------------------- |
| INIT          | V1, V2                                  |
| HELLO         | V3, V4.x, v5.1, v5.2, v5.3, v5.4        |
| LOGON         | V3, V4.x, v5.1, v5.2, v5.3, v5.4        |
| RUN           | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4|
| PULL          | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4|
| BEGIN         | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4|
| COMMIT        | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4|
| ROLLBACK      | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4|
| LOGOFF        | V3, V4.x, v5.1, v5.2, v5.3, v5.4        |
| TELEMETRY     | --                                      |
| GOODBYE       | V3, V4.x, v5.1, v5.2, v5.3, v5.4        |
| RESET         | V3, V4.x, v5.1, v5.2, v5.3, v5.4        |
| DISCARD       | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4|
| ROUTE         | --                                      |
| ACK_FAILURE   | V1, V2                                  |

