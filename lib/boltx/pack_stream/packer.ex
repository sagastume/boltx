defprotocol Boltx.PackStream.Packer do
  @moduledoc """
  The `Boltx.PackStream.Packer` protocol is responsible for serializing any Elixir data
  structure according to the PackStream specification.

  ##  Serializing for structs
  By default, all structures are serialized with all their fields. However, if it is
  necessary that only certain fields be considered for serialization, it is necessary to
  perform a derivation. Below is an example:

      defmodule Book do
        @derive [{Boltx.PackStream.Packer, fields: [:name]}]
        defstruct [:name, :other_data]
      end`

  """
  @fallback_to_any true
  def pack(term)
end

defimpl Boltx.PackStream.Packer, for: Atom do
  use Boltx.PackStream.Markers

  def pack(nil), do: <<@null_marker>>
  def pack(false), do: <<@false_marker>>
  def pack(true), do: <<@true_marker>>

  def pack(atom) do
    atom
    |> Atom.to_string()
    |> @protocol.BitString.pack()
  end
end

defimpl Boltx.PackStream.Packer, for: BitString do
  use Boltx.PackStream.Markers

  def pack(binary) when is_binary(binary) do
    [marker(binary), binary]
  end

  def pack(bits) do
    throw(Boltx.Error.wrap(__MODULE__, :not_encodable, bits: bits))
  end

  defp marker(binary) do
    size = byte_size(binary)

    cond do
      size <= 15 -> <<@tiny_bitstring_marker::4, size::4>>
      size <= 255 -> <<@bitstring8_marker, size::8>>
      size <= 65_535 -> <<@bitstring16_marker, size::16>>
      size <= 4_294_967_295 -> <<@bitstring32_marker, size::32>>
      true -> throw(Boltx.Error.wrap(__MODULE__, :not_encodable_too_big, bits: binary))
    end
  end
end

defimpl Boltx.PackStream.Packer, for: Integer do
  use Boltx.PackStream.Markers

  def pack(integer) when integer in -16..127 do
    <<integer>>
  end

  def pack(integer) do
    case integer do
      integer when integer in @int8 ->
        <<@int8_marker, integer>>

      integer when integer in @int16_low when integer in @int16_high ->
        <<@int16_marker, integer::16>>

      integer when integer in @int32_low when integer in @int32_high ->
        <<@int32_marker, integer::32>>

      integer when integer in @int64_low when integer in @int64_high ->
        <<@int64_marker, integer::64>>
    end
  end
end

defimpl Boltx.PackStream.Packer, for: Float do
  use Boltx.PackStream.Markers

  def pack(number) do
    <<@float_marker, number::float>>
  end
end

defimpl Boltx.PackStream.Packer, for: List do
  use Boltx.PackStream.Markers

  def pack(list) do
    [marker(list), list |> Enum.map(&@protocol.pack(&1))]
  end

  defp marker(list) do
    length = length(list)

    cond do
      length <= 15 -> <<@tiny_list_marker::4, length::4>>
      length <= 255 -> <<@list8_marker, length::8>>
      length <= 65_535 -> <<@list16_marker, length::16>>
      length <= 4_294_967_295 -> <<@list32_marker, length::32>>
      true -> throw(Boltx.Error.wrap(__MODULE__, :not_encodable_too_big, bits: list))
    end
  end
end

defimpl Boltx.PackStream.Packer, for: Map do
  use Boltx.PackStream.Markers

  def pack(map) do
    [marker(map), map |> encode_kv()]
  end

  defp marker(map) do
    length = map_size(map)

    cond do
      length <= 15 -> <<@tiny_map_marker::4, length::4>>
      length <= 255 -> <<@map8_marker, length::8>>
      length <= 65_535 -> <<@map16_marker, length::16>>
      length <= 4_294_967_295 -> <<@map32_marker, length::32>>
      true -> throw(Boltx.Error.wrap(__MODULE__, :not_encodable_too_big, bits: map))
    end
  end

  @spec encode_kv(map()) :: binary()
  defp encode_kv(map) do
    Enum.reduce(map, <<>>, fn data, acc -> [acc, do_reduce_kv(data)] end)
  end

  @spec do_reduce_kv({atom(), any()}) :: [binary()]
  defp do_reduce_kv({key, value}) do
    [
      @protocol.pack(key),
      @protocol.pack(value)
    ]
  end
end

defimpl Boltx.PackStream.Packer, for: Time do
  use Boltx.PackStream.Markers

  def pack(time) do
    local_time = day_time(time)

    [
      <<@tiny_struct_marker::4, @local_time_struct_size::4, @local_time_signature>>,
      @protocol.pack(local_time)
    ]
  end

  @spec day_time(Time.t()) :: integer()
  defp day_time(time) do
    Time.diff(time, ~T[00:00:00.000], :nanosecond)
  end
end

defimpl Boltx.PackStream.Packer, for: Date do
  use Boltx.PackStream.Markers

  def pack(date) do
    epoch = Date.diff(date, ~D[1970-01-01])
    [<<@tiny_struct_marker::4, @date_struct_size::4, @date_signature>>, @protocol.pack(epoch)]
  end
end

defimpl Boltx.PackStream.Packer, for: DateTime do
  use Boltx.PackStream.Markers

  def pack(datetime) do
    data =
      Enum.map(
        decompose_datetime(DateTime.to_naive(datetime)) ++ [datetime.time_zone],
        &@protocol.pack(&1)
      )

    [
      <<@tiny_struct_marker::4, @legacy_datetime_with_zone_id_struct_size::4,
        @legacy_datetime_with_zone_id_signature>>,
      data
    ]
  end

  @spec decompose_datetime(Calendar.naive_datetime()) :: [integer()]
  defp decompose_datetime(%NaiveDateTime{} = datetime) do
    datetime_micros = NaiveDateTime.diff(datetime, ~N[1970-01-01 00:00:00.000], :microsecond)

    seconds = div(datetime_micros, 1_000_000)
    nanoseconds = rem(datetime_micros, 1_000_000) * 1_000

    [seconds, nanoseconds]
  end
end

defimpl Boltx.PackStream.Packer, for: NaiveDateTime do
  use Boltx.PackStream.Markers

  def pack(local_datetime) do
    data =
      Enum.map(
        decompose_datetime(local_datetime),
        &@protocol.pack(&1)
      )

    [<<@tiny_struct_marker::4, @local_datetime_struct_size::4, @local_datetime_signature>>, data]
  end

  @spec decompose_datetime(Calendar.naive_datetime()) :: [integer()]
  defp decompose_datetime(%NaiveDateTime{} = datetime) do
    datetime_micros = NaiveDateTime.diff(datetime, ~N[1970-01-01 00:00:00.000], :microsecond)

    seconds = div(datetime_micros, 1_000_000)
    nanoseconds = rem(datetime_micros, 1_000_000) * 1_000

    [seconds, nanoseconds]
  end
end

defimpl Boltx.PackStream.Packer, for: Boltx.Types.TimeWithTZOffset do
  use Boltx.PackStream.Markers

  def pack(%Boltx.Types.TimeWithTZOffset{time: time, timezone_offset: offset}) do
    time_and_offset = [day_time(time), offset]

    data =
      Enum.map(
        time_and_offset,
        &@protocol.pack(&1)
      )

    [<<@tiny_struct_marker::4, @time_with_tz_struct_size::4, @time_with_tz_signature>>, data]
  end

  @spec day_time(Time.t()) :: integer()
  defp day_time(time) do
    Time.diff(time, ~T[00:00:00.000], :nanosecond)
  end
end

defimpl Boltx.PackStream.Packer, for: Boltx.Types.DateTimeWithTZOffset do
  use Boltx.PackStream.Markers

  def pack(%Boltx.Types.DateTimeWithTZOffset{naive_datetime: ndt, timezone_offset: tz_offset}) do
    data =
      Enum.map(
        decompose_datetime(ndt) ++ [tz_offset],
        &@protocol.pack(&1)
      )

    [
      <<@tiny_struct_marker::4, @legacy_datetime_with_zone_offset_struct_size::4,
        @legacy_datetime_with_zone_offset_signature>>,
      data
    ]
  end

  @spec decompose_datetime(Calendar.naive_datetime()) :: [integer()]
  defp decompose_datetime(%NaiveDateTime{} = datetime) do
    datetime_micros = NaiveDateTime.diff(datetime, ~N[1970-01-01 00:00:00.000], :microsecond)

    seconds = div(datetime_micros, 1_000_000)
    nanoseconds = rem(datetime_micros, 1_000_000) * 1_000

    [seconds, nanoseconds]
  end
end

defimpl Boltx.PackStream.Packer, for: Boltx.Types.Duration do
  use Boltx.PackStream.Markers

  def pack(duration) do
    data =
      Enum.map(
        compact_duration(duration),
        &@protocol.pack(&1)
      )

    [<<@tiny_struct_marker::4, @duration_struct_size::4, @duration_signature>>, data]
  end

  @spec compact_duration(Boltx.Types.Duration.t()) :: [integer()]
  defp compact_duration(%Boltx.Types.Duration{} = duration) do
    months = 12 * duration.years + duration.months
    days = 7 * duration.weeks + duration.days
    seconds = 3600 * duration.hours + 60 * duration.minutes + duration.seconds

    [months, days, seconds, duration.nanoseconds]
  end
end

defimpl Boltx.PackStream.Packer, for: Boltx.Types.Point do
  use Boltx.PackStream.Markers

  def pack(%Boltx.Types.Point{z: nil} = point) do
    data =
      Enum.map(
        [point.srid, point.x, point.y],
        &@protocol.pack(&1)
      )

    [<<@tiny_struct_marker::4, @point2d_struct_size::4, @point2d_signature>>, data]
  end

  def pack(%Boltx.Types.Point{} = point) do
    data =
      Enum.map(
        [point.srid, point.x, point.y, point.z],
        &@protocol.pack(&1)
      )

    [<<@tiny_struct_marker::4, @point3d_struct_size::4, @point3d_signature>>, data]
  end
end

defimpl Boltx.PackStream.Packer, for: Any do
  defmacro __deriving__(module, struct, options) do
    deriving(module, struct, options)
  end

  def deriving(module, struct, options) do
    keys = struct |> Map.from_struct() |> Map.keys()
    fields = Keyword.get(options, :fields, keys)
    include_struct_field? = Keyword.get(options, :include_struct_field, :__struct__ in fields)
    fields = List.delete(fields, :__struct__)

    extractor =
      cond do
        fields == keys and include_struct_field? ->
          quote(do: Map.from_struct(struct) |> Map.put("__struct__", unquote(module)))

        fields == keys ->
          quote(do: Map.from_struct(struct))

        include_struct_field? ->
          quote(do: Map.take(struct, unquote(fields)) |> Map.put("__struct__", unquote(module)))

        true ->
          quote(do: Map.take(struct, unquote(fields)))
      end

    quote do
      defimpl unquote(@protocol), for: unquote(module) do
        def pack(struct) do
          unquote(extractor)
          |> @protocol.Map.pack()
        end
      end
    end
  end

  def pack(%{__struct__: _} = struct) do
    @protocol.Map.pack(Map.from_struct(struct))
  end

  def pack(term) do
    raise Protocol.UndefinedError, protocol: @protocol, value: term
  end
end
