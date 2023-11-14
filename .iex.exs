try do
  Code.eval_file(".iex.exs", "~")
rescue
  Code.LoadError -> :rescued
end

alias Boltx.{Utils, Protocol, Router, ConnectionSupervisor, Response}
alias Boltx

Application.put_env(:tzdata, :autoupdate, :disabled)

# default port considered to be: 7687
test_config = [
  # url: 'localhost',
  url: "bolt://localhost",
  basic_auth: [username: "neo4j", password: "test"],
  pool_size: 5,
  max_overflow: 1,
  # retry the request, in case of error - in the example below the retry will
  # linearly increase the delay from 150ms following a Fibonacci pattern,
  # cap the delay at 15 seconds (the value defined by the default `:timeout`
  # parameter) and giving up after 3 attempts
  retry_linear_backoff: [delay: 150, factor: 2, tries: 3],
  read: [pool_size: 5, pool_overflow: 0],
  write: [pool_size: 1, pool_overflow: 0]
]

Mix.shell().info([
  :green,
  """
  Optional, if needed for development (Boltx is the alias for Boltx):
    {:ok, _neo} = Boltx.start_link(url: "bolt://neo4j:test@localhost")
    conn = Boltx.conn()
  Examples:
    Boltx.query!(conn, "UNWIND range(1, 10) AS n RETURN n")
    Boltx.query!(conn, "RETURN 1 as n")
  --- ✄  -------------------------------------------------

  """
])
