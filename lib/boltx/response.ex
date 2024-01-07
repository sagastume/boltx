defmodule Boltx.Response do
  import Boltx.BoltProtocol.ServerResponse

  @type t :: %__MODULE__{
          results: list,
          fields: list,
          records: list,
          plan: map,
          notifications: list,
          stats: list | map,
          profile: any,
          type: String.t(),
          bookmark: String.t()
        }

  @type key :: any
  @type value :: any
  @type acc :: any
  @type element :: any

  @doc """
  Una estructura que representa una consulta Boltx.

  * `statement` - La declaración de la consulta.
  * `extra` - Datos adicionales asociados con la consulta.
  """
  defstruct results: [],
            fields: nil,
            records: [],
            plan: nil,
            notifications: [],
            stats: [],
            profile: nil,
            type: nil,
            bookmark: nil

  def new(
        statement_result(
          result_run: result_run,
          result_pull: pull_result(records: records, success_data: success_data)
        )
      ) do
    fields = Map.get(result_run, "fields", [])

    %__MODULE__{
      results: create_results(fields, records),
      fields: fields,
      records: records,
      plan: Map.get(success_data, "plan", nil),
      notifications: Map.get(success_data, "notifications", []),
      stats: Map.get(success_data, "stats", []),
      profile: Map.get(success_data, "profile", nil),
      type: Map.get(success_data, "type", nil),
      bookmark: Map.get(success_data, "bookmark", nil)
    }
  end

  def first(%__MODULE__{results: []}), do: nil
  def first(%__MODULE__{results: [head | _tail]}), do: head

  defp create_results(fields, records) do
    records
    |> Enum.map(fn recs -> Enum.zip(fields, recs) end)
    |> Enum.map(fn data -> Enum.into(data, %{}) end)
  end
end
