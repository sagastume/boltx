defmodule Boltx.BoltProtocol.Versions do
  @moduledoc false

  @available_bolt_versions [1.0, 2.0, 3.0, 4.0, 4.1, 4.2, 4.3, 4.4, 5.0, 5.1, 5.2, 5.3, 5.4]

  def available_versions() do
    @available_bolt_versions
  end

  def latest_versions() do
    ((available_versions() |> Enum.sort(&>=/2) |> rangeify()) ++ [{0, 0}, {0, 0}, {0, 0}]) |> Enum.take(4)
  end

  def to_bytes(version) when is_float(version) do
    [major | [minor]] =
      version |> Float.to_string() |> String.split(".") |> Enum.map(&String.to_integer/1)
    <<0, 0>> <> <<minor, major>>
  end

  def to_bytes(version) when is_integer(version) do
    to_bytes(version + 0.0)
  end

  def to_bytes(version) when is_tuple(version) do
    {major, minor_or_range} = version
    cond do
      is_integer(minor_or_range) ->
        <<0, 0>> <> <<minor_or_range, major>>
      is_struct(minor_or_range, Range) ->
        minor = List.last(Range.to_list(minor_or_range))
        previous = Range.size(minor_or_range) - 1
        <<0>> <> <<previous, minor, major>>
    end
  end

  def rangeify(list) when is_list(list) do
    Enum.into(list, [],
      fn version ->
        cond do
          is_float(version) ->
            [major | [minor]] = version |> Float.to_string() |> String.split(".") |> Enum.map(&String.to_integer/1)
            {major, minor}
          is_integer(version) ->
            {version, 0}
        end
      end)

    |> Enum.reduce([],
      fn value, acc ->
        {major, minor} = value
        cond do
          acc == [] -> [value]
          major < 4 -> [value | acc ]
          major == 4 and minor < 3 -> [value | acc]
          true ->
            [{prev_major, prev_minor_or_range} | tail] = acc
            cond do
              major < prev_major -> [value | acc]
              is_integer(prev_minor_or_range) -> [{prev_major, Range.new(minor, prev_minor_or_range)} | tail ]
              true -> [{prev_major, Range.new(minor, List.last(Range.to_list(prev_minor_or_range)))} | tail ]
            end
        end
      end)
    |> Enum.reverse()
  end
end
