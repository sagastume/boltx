defmodule Boltx.PackStream.Unpacker do
  @moduledoc false

  use Boltx.PackStream.Markers

  alias Boltx.Types.{
    TimeWithTZOffset,
    DateTimeWithTZOffset,
    Duration,
    Point,
    Relationship,
    UnboundRelationship,
    Node,
    Path
  }

  # Null
  def unpack(<<@null_marker, rest::binary>>) do
    [nil | unpack(rest)]
  end

  # Boolean
  def unpack(<<@true_marker, rest::binary>>) do
    [true | unpack(rest)]
  end

  def unpack(<<@false_marker, rest::binary>>) do
    [false | unpack(rest)]
  end

  # Float
  def unpack(<<@float_marker, number::float, rest::binary>>) do
    [number | unpack(rest)]
  end

  # Strings
  def unpack(<<@tiny_bitstring_marker::4, str_length::4, rest::bytes>>) do
    decode_string(rest, str_length)
  end

  def unpack(<<@bitstring8_marker, str_length, rest::bytes>>) do
    decode_string(rest, str_length)
  end

  def unpack(<<@bitstring16_marker, str_length::16, rest::bytes>>) do
    decode_string(rest, str_length)
  end

  def unpack(<<@bitstring32_marker, str_length::32, rest::binary>>) do
    decode_string(rest, str_length)
  end

  # Lists
  def unpack(<<@tiny_list_marker::4, list_size::4>> <> bin) do
    decode_list(bin, list_size)
  end

  def unpack(<<@list8_marker, list_size::8>> <> bin) do
    decode_list(bin, list_size)
  end

  def unpack(<<@list16_marker, list_size::16>> <> bin) do
    decode_list(bin, list_size)
  end

  def unpack(<<@list32_marker, list_size::32>> <> bin) do
    decode_list(bin, list_size)
  end

  # Maps
  def unpack(<<@tiny_map_marker::4, entries::4>> <> bin) do
    decode_map(bin, entries)
  end

  def unpack(<<@map8_marker, entries::8>> <> bin) do
    decode_map(bin, entries)
  end

  def unpack(<<@map16_marker, entries::16>> <> bin) do
    decode_map(bin, entries)
  end

  def unpack(<<@map32_marker, entries::32>> <> bin) do
    decode_map(bin, entries)
  end

  # Struct
  def unpack(<<@tiny_struct_marker::4, struct_size::4, sig::8>> <> struct) do
    unpack({sig, struct, struct_size})
  end

  def unpack(<<@struct8_marker, struct_size::8, sig::8>> <> struct) do
    unpack({sig, struct, struct_size})
  end

  def unpack(<<@struct16_marker, struct_size::16, sig::8>> <> struct) do
    unpack({sig, struct, struct_size})
  end

  ######### SPECIAL STRUCTS

  # Node
  def unpack({@node_marker, struct, struct_size}) do
    {structure_data, rest} = decode_struct(struct, struct_size)

    field_names = [:id, :labels, :properties, :element_id]
    node_data = Enum.zip([field_names, structure_data])
    node = struct(Node, node_data)

    [node | rest]
  end

  # Relationship
  def unpack({@relationship_marker, struct, struct_size}) do
    {structure_data, rest} =
      decode_struct(struct, struct_size)

    field_names = [
      :id,
      :start,
      :end,
      :type,
      :properties,
      :element_id,
      :start_node_element_id,
      :end_node_element_id
    ]

    relationship_data = Enum.zip([field_names, structure_data])
    relationship = struct(Relationship, relationship_data)

    [relationship | rest]
  end

  # UnboundedRelationship
  def unpack({@unbounded_relationship_marker, struct, struct_size}) do
    {structure_data, rest} = decode_struct(struct, struct_size)

    field_names = [:id, :type, :properties, :element_id]
    unbounded_relationship_data = Enum.zip([field_names, structure_data])
    unbounded_relationship = struct(UnboundRelationship, unbounded_relationship_data)

    [unbounded_relationship | rest]
  end

  # Path
  def unpack({@path_marker, struct, struct_size}) do
    {structure_data, rest} =
      decode_struct(struct, struct_size)

    field_names = [:nodes, :relationships, :sequence]
    path_data = Enum.zip([field_names, structure_data])
    path = struct(Path, path_data)

    [path | rest]
  end

  # Manage the end of data
  def unpack(<<>>), do: []

  # Integer
  def unpack(<<@int8_marker, int::signed-integer, rest::binary>>) do
    [int | unpack(rest)]
  end

  def unpack(<<@int16_marker, int::signed-integer-16, rest::binary>>) do
    [int | unpack(rest)]
  end

  def unpack(<<@int32_marker, int::signed-integer-32, rest::binary>>) do
    [int | unpack(rest)]
  end

  def unpack(<<@int64_marker, int::signed-integer-64, rest::binary>>) do
    [int | unpack(rest)]
  end

  def unpack(<<int::signed-integer, rest::binary>>) do
    [int | unpack(rest)]
  end

  # Local Date
  def unpack({@date_signature, struct, @date_struct_size}) do
    {[date], rest} = decode_struct(struct, @date_struct_size)
    [Date.add(~D[1970-01-01], date) | rest]
  end

  # Local Time
  def unpack({@local_time_signature, struct, @local_time_struct_size}) do
    {[time], rest} = decode_struct(struct, @local_time_struct_size)

    [Time.add(~T[00:00:00.000000], time, :nanosecond) | rest]
  end

  # Local DateTime
  def unpack({@local_datetime_signature, struct, @local_datetime_struct_size}) do
    {[seconds, nanoseconds], rest} =
      decode_struct(struct, @local_datetime_struct_size)

    ndt =
      NaiveDateTime.add(
        ~N[1970-01-01 00:00:00.000000000],
        seconds * 1_000_000_000 + nanoseconds,
        :nanosecond
      )

    [ndt | rest]
  end

  # Time with Zone Offset
  def unpack({@time_with_tz_signature, struct, @time_with_tz_struct_size}) do
    {[time, offset], rest} = decode_struct(struct, @time_with_tz_struct_size)

    t = TimeWithTZOffset.create(Time.add(~T[00:00:00.000000], time, :nanosecond), offset)
    [t | rest]
  end

  # Legacy Datetime with zone Id
  def unpack(
        {@legacy_datetime_with_zone_id_signature, struct,
         @legacy_datetime_with_zone_id_struct_size}
      ) do
    {[seconds, nanoseconds, zone_id], rest} =
      decode_struct(struct, @legacy_datetime_with_zone_id_struct_size)

    naive_dt =
      NaiveDateTime.add(
        ~N[1970-01-01 00:00:00.000000],
        seconds * 1_000_000_000 + nanoseconds,
        :nanosecond
      )

    dt = Boltx.TypesHelper.datetime_with_micro(naive_dt, zone_id)
    [dt | rest]
  end

  # Datetime with zone Id
  def unpack({@datetime_with_zone_id_signature, struct, @datetime_with_zone_id_struct_size}) do
    {[seconds, nanoseconds, zone_id], rest} =
      decode_struct(struct, @datetime_with_zone_id_struct_size)

    {:ok, date_from_unix} = DateTime.from_unix(seconds * 1_000_000_000 + nanoseconds, :nanosecond)
    {:ok, datetime} = DateTime.shift_zone(date_from_unix, zone_id)
    [datetime | rest]
  end

  # Legacy Datetime with zone offset
  def unpack(
        {@legacy_datetime_with_zone_offset_signature, struct,
         @legacy_datetime_with_zone_offset_struct_size}
      ) do
    {[seconds, nanoseconds, zone_offset], rest} =
      decode_struct(struct, @legacy_datetime_with_zone_id_struct_size)

    naive_dt =
      NaiveDateTime.add(
        ~N[1970-01-01 00:00:00.000000],
        seconds * 1_000_000_000 + nanoseconds,
        :nanosecond
      )

    dt = DateTimeWithTZOffset.create(naive_dt, zone_offset)
    [dt | rest]
  end

  # Datetime with zone offset
  def unpack(
        {@datetime_with_zone_offset_signature, struct, @datetime_with_zone_offset_struct_size}
      ) do
    {[seconds, nanoseconds, zone_offset], rest} =
      decode_struct(struct, @legacy_datetime_with_zone_id_struct_size)

    naive_dt =
      NaiveDateTime.add(
        ~N[1970-01-01 00:00:00.000000],
        (seconds + zone_offset) * 1_000_000_000 + nanoseconds,
        :nanosecond
      )

    dt = DateTimeWithTZOffset.create(naive_dt, zone_offset)
    [dt | rest]
  end

  # Duration
  def unpack({@duration_signature, struct, @duration_struct_size}) do
    {[months, days, seconds, nanoseconds], rest} =
      decode_struct(struct, @duration_struct_size)

    duration = Duration.create(months, days, seconds, nanoseconds)
    [duration | rest]
  end

  # Point2D
  def unpack({@point2d_signature, struct, @point2d_struct_size}) do
    {[srid, x, y], rest} = decode_struct(struct, @point2d_struct_size)
    point = Point.create(srid, x, y)

    [point | rest]
  end

  # Point3D
  def unpack({@point3d_signature, struct, @point3d_struct_size}) do
    {[srid, x, y, z], rest} = decode_struct(struct, @point3d_struct_size)
    point = Point.create(srid, x, y, z)

    [point | rest]
  end

  # Private
  @spec decode_string(binary(), integer()) :: list()
  defp decode_string(bytes, str_length) do
    <<string::binary-size(str_length), rest::binary>> = bytes

    [string | unpack(rest)]
  end

  @spec decode_list(binary(), integer()) :: list()
  defp decode_list(list, list_size) do
    {list, rest} = list |> unpack() |> Enum.split(list_size)
    [list | rest]
  end

  @spec decode_map(binary(), integer()) :: list()
  defp decode_map(map, entries) do
    {map, rest} = map |> unpack() |> Enum.split(entries * 2)

    [to_map(map) | rest]
  end

  @spec decode_struct(binary(), integer()) :: {list(), list()}
  def decode_struct(struct, struct_size) do
    struct
    |> unpack()
    |> Enum.split(struct_size)
  end

  @spec to_map(list()) :: map()
  defp to_map(map) do
    map
    |> Enum.chunk_every(2)
    |> Enum.map(&List.to_tuple/1)
    |> Map.new()
  end
end
