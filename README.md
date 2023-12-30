# Boltx

`Boltx` is an Elixir driver for [Neo4j](https://neo4j.com/developer/graph-database/)/Bolt Protocol.

- Supports Neo4j versions: 3.0.x/3.1.x/3.2.x/3.4.x/3.5.x/4.x/5.9 -5.13.0
- Supports Bolt version: 1.0/2.0/3.0/4.x/5.0/5.1/5.2/5.3/5.4
- Supports transactions, prepared queries, streaming, pooling and more via DBConnection
- Automatic decoding and encoding of Elixir values

Documentation: [https://hexdocs.pm/boltx](https://hexdocs.pm/boltx/)

## Features

| Feature               | Implemented |
| --------------------- | ------------ |
| Querys                | YES          |
| Transactions          | YES          |
| Multi tenancy         | NO           |
| Stream capabilities   | NO           |
| Routing               | NO           |

### Usage

Add :boltx to your dependencies:

```elixir
def deps() do
  [
    {:boltx, "~> 0.0.2"}
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

