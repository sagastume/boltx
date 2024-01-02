defmodule Boltx.Internals.PackStream.EncoderTest do
  use ExUnit.Case, async: false

  alias Boltx.Internals.PackStream.Encoder
  alias Boltx.Internals.BoltVersionHelper
  alias Boltx.Types
  alias Boltx.TypesHelper

  @moduletag :legacy

  defmodule TestStruct do
    defstruct foo: "bar"
  end

  describe "Encode common types:" do
    Enum.each(BoltVersionHelper.available_versions(), fn bolt_version ->
      test "raises error when trying to encode with unknown signature (bolt_version: #{bolt_version})" do
        assert_raise Boltx.Internals.PackStreamError, ~r/^unable to encode/i, fn ->
          Encoder.encode({128, []}, unquote(bolt_version))
        end

        assert_raise Boltx.Internals.PackStreamError, ~r/^unable to encode/i, fn ->
          Encoder.encode({-1, []}, unquote(bolt_version))
        end

        assert_raise Boltx.Internals.PackStreamError, ~r/^unable to encode/i, fn ->
          Encoder.encode({"a", []}, unquote(bolt_version))
        end
      end

      test "unkown type (bolt_version: #{bolt_version})" do
        assert_raise Boltx.Internals.PackStreamError, fn ->
          Encoder.encode({:error, "unencodable"}, unquote(bolt_version))
        end
      end
    end)
  end

  describe "Encode types for bolt >= 2" do
    BoltVersionHelper.available_versions()
    |> Enum.filter(&(&1 >= 2))
    |> Enum.each(fn bolt_version ->
      test "Local time (bolt_version: #{bolt_version})" do
        assert <<0xB1, 0x74, _::binary>> =
                 :erlang.iolist_to_binary(Encoder.encode(~T[14:45:53.34], unquote(bolt_version)))
      end

      test "Time with TZ Offset (bolt_version: #{bolt_version})" do
        assert <<0xB2, 0x54, _::binary>> =
                 :erlang.iolist_to_binary(
                   Encoder.encode(
                     Types.TimeWithTZOffset.create(~T[12:45:30.250000], 3600),
                     unquote(bolt_version)
                   )
                 )
      end

      test "Date (bolt_version: #{bolt_version})" do
        assert <<0xB1, 0x44, _::binary>> =
                 :erlang.iolist_to_binary(Encoder.encode(~D[2013-05-06], unquote(bolt_version)))
      end

      test "Local date time: NaiveDateTime (bolt_version: #{bolt_version})" do
        assert <<0xB2, 0x64, _::binary>> =
                 :erlang.iolist_to_binary(
                   Encoder.encode(~N[2018-04-05 12:34:00.543], unquote(bolt_version))
                 )
      end

      test "Datetime with timezone offset (bolt_version: #{bolt_version})" do
        assert <<0xB3, 0x46, _::binary>> =
                 :erlang.iolist_to_binary(
                   Encoder.encode(
                     Types.DateTimeWithTZOffset.create(~N[2016-05-24 13:26:08.543], 7200),
                     unquote(bolt_version)
                   )
                 )
      end

      test "Datetime with timezone id (bolt_version: #{bolt_version})" do
        assert <<0xB3, 0x66, _::binary>> =
                 :erlang.iolist_to_binary(
                   Encoder.encode(
                     TypesHelper.datetime_with_micro(
                       ~N[2016-05-24 13:26:08.543],
                       "Europe/Berlin"
                     ),
                     unquote(bolt_version)
                   )
                 )
      end

      test "Duration (bolt_version: #{bolt_version})" do
        duration = %Types.Duration{
          years: 2,
          months: 3,
          weeks: 2,
          days: 23,
          hours: 8,
          minutes: 2,
          seconds: 4,
          nanoseconds: 3234
        }

        assert <<0xB4, 0x45, _::binary>> =
                 :erlang.iolist_to_binary(Encoder.encode(duration, unquote(bolt_version)))
      end

      test "Point 2D cartesian (bolt_version: #{bolt_version})" do
        assert <<0xB3, 0x58, _::binary>> =
                 :erlang.iolist_to_binary(
                   Encoder.encode(Types.Point.create(:cartesian, 40, 45), unquote(bolt_version))
                 )
      end

      test "Point 2D geographic (bolt_version: #{bolt_version})" do
        assert <<0xB3, 0x58, _::binary>> =
                 :erlang.iolist_to_binary(
                   Encoder.encode(Types.Point.create(:wgs_84, 40, 45), unquote(bolt_version))
                 )
      end

      test "Point 3D cartesian (bolt_version: #{bolt_version})" do
        assert <<0xB4, 0x59, _::binary>> =
                 :erlang.iolist_to_binary(
                   Encoder.encode(
                     Types.Point.create(:cartesian, 40, 45, 150),
                     unquote(bolt_version)
                   )
                 )
      end

      test "Point 3D geographic (bolt_version: #{bolt_version})" do
        assert <<0xB4, 0x59, _::binary>> =
                 :erlang.iolist_to_binary(
                   Encoder.encode(Types.Point.create(:wgs_84, 40, 45, 150), unquote(bolt_version))
                 )
      end
    end)
  end
end
