defmodule Boltx.BoltProtocol.ServerResponse do
  import Record

  defrecord :statement_result, [
    :result_run,
    :result_pull,
    :query
  ]

  defrecord :pull_result, [
    :records,
    :success_data
  ]
end
