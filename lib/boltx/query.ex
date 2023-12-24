defmodule Boltx.Query do
  @moduledoc false
  defstruct statement: "",
            extra: %{}
end

defmodule Boltx.Queries do
  defstruct statement: "",
            extra: %{}
end

defimpl DBConnection.Query, for: [Boltx.Query, Boltx.Queries] do
  def describe(query, _), do: query

  def parse(query, _), do: query

  def encode(_query, data, _), do: data

  def decode(_, result, _), do: result
end
