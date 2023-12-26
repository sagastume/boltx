defmodule Boltx do
  @moduledoc """
  Bolt driver for Elixir.
  """

  @type conn() :: DBConnection.conn()

  alias Boltx.{Types}

  def start_link(options) do
    DBConnection.start_link(Boltx.Connection, options)
  end

  def query(conn, statement, params \\ %{}, opts \\ []) do
    formatted_params =
      params
      |> Enum.map(&format_param/1)
      |> Enum.map(fn {k, {:ok, value}} -> {k, value} end)
      |> Map.new()

    query = %Boltx.Query{statement: statement}
    do_query(conn, query, formatted_params, opts)
  end

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
