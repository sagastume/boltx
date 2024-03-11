defmodule Boltx.PackStreamTest do
  use ExUnit.Case, async: true

  alias Boltx.PackStream
  alias Boltx.Types.{TimeWithTZOffset, DateTimeWithTZOffset, Duration, Point}
  alias Boltx.TypesHelper
  alias Boltx.TestDerivationStruct

  defmodule TestStruct do
    defstruct foo: "bar"
  end

  describe "Encode data types" do
    @describetag :core

    test "encode a nil" do
      assert PackStream.pack!(nil) == <<0xC0>>
    end

    test "encodes boolean" do
      assert PackStream.pack!(true) == <<0xC3>>
      assert PackStream.pack!(false) == <<0xC2>>
    end

    test "encodes atom" do
      assert PackStream.pack!(:hello) == <<0x85, 0x68, 0x65, 0x6C, 0x6C, 0x6F>>
      assert PackStream.pack!(true) == <<0xC3>>
      assert PackStream.pack!(false) == <<0xC2>>
      assert PackStream.pack!(nil) == <<0xC0>>
    end

    test "encodes integer" do
      assert PackStream.pack!(0) == <<0x00>>
      assert PackStream.pack!(7) == <<0x7>>
      assert PackStream.pack!(42) == <<0x2A>>
      assert PackStream.pack!(-42) == <<0xC8, 0xD6>>
      assert PackStream.pack!(420) == <<0xC9, 0x01, 0xA4>>
      assert PackStream.pack!(33_000) == <<0xCA, 0x00, 0x00, 0x80, 0xE8>>

      assert PackStream.pack!(2_150_000_000) ==
               <<0xCB, 0x00, 0x00, 0x00, 0x00, 0x80, 0x26, 0x65, 0x80>>
    end

    test "encodes float" do
      assert PackStream.pack!(+1.1) ==
               <<0xC1, 0x3F, 0xF1, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9A>>

      assert PackStream.pack!(-1.1) ==
               <<0xC1, 0xBF, 0xF1, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9A>>

      assert PackStream.pack!(7.7) ==
               <<0xC1, 0x40, 0x1E, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCD>>
    end

    test "encodes string" do
      assert PackStream.pack!("") == <<0x80>>
      assert PackStream.pack!("Short") == <<0x85, 0x53, 0x68, 0x6F, 0x72, 0x74>>
      assert PackStream.pack!("hello") == <<0x85, 0x68, 0x65, 0x6C, 0x6C, 0x6F>>

      # 30 bytes due to umlauts
      long_8 = "This is a räther löng string"

      assert <<0xD0, 0x1E, _::binary-size(30)>> = PackStream.pack!(long_8)

      long_16 = """
      For encoded string containing fewer than 16 bytes, including empty strings,
      the marker byte should contain the high-order nibble `1000` followed by a
      low-order nibble containing the size. The encoded data then immediately
      follows the marker.

      For encoded string containing 16 bytes or more, the marker 0xD0, 0xD1 or
      0xD2 should be used, depending on scale. This marker is followed by the
      size and the UTF-8 encoded data.
      """

      assert <<0xD1, 0x01, 0xA5, _::binary-size(421)>> = PackStream.pack!(long_16)

      long_32 = String.duplicate("a", 66_000)

      assert <<0xD2, 66_000::32, _::binary-size(66_000)>> = PackStream.pack!(long_32)
    end

    test "encodes list" do
      assert PackStream.pack!([]) == <<0x90>>
      assert PackStream.pack!([2, 4]) == <<0x92, 0x2, 0x4>>

      list_8 = Stream.repeatedly(fn -> "a" end) |> Enum.take(16)

      assert <<0xD4, 16::8, _::binary-size(32)>> = PackStream.pack!(list_8)

      list_16 = Stream.repeatedly(fn -> "a" end) |> Enum.take(256)

      assert <<0xD5, 256::16, _::binary-size(512)>> = PackStream.pack!(list_16)

      list_32 = Stream.repeatedly(fn -> "a" end) |> Enum.take(66_000)

      assert <<0xD6, 66_000::32, _::binary-size(132_000)>> = PackStream.pack!(list_32)
    end

    test "encodes map" do
      assert PackStream.pack!(%{}) == <<0xA0>>
      assert PackStream.pack!(%{ok: 5}) == <<0xA1, 0x82, 0x6F, 0x6B, 0x5>>

      map_8 = 1..16 |> Enum.map(&{&1, "a"}) |> Map.new()
      assert <<0xD8, 16::8>> <> _rest = PackStream.pack!(map_8)

      map_16 = 1..256 |> Enum.map(&{&1, "a"}) |> Map.new()
      assert <<0xD9, 256::16>> <> _rest = PackStream.pack!(map_16)

      map_32 = 1..66_000 |> Enum.map(&{&1, "a"}) |> Map.new()

      assert <<0xDA, 66_000::32>> <> _rest = PackStream.pack!(map_32)
    end

    test "encodes a struct" do
      assert <<161, 131, 102, 111, 111, 131, 98, 97, 114>> == PackStream.pack!(%TestStruct{})

      assert <<161, 131, 102, 111, 111, 131, 98, 97, 114>> ==
               PackStream.pack!(%TestDerivationStruct{})
    end
  end

  describe "Encode temporal types:" do
    @describetag :core

    test "encodes a Local time" do
      assert <<0xB1, 0x74, _::binary>> = PackStream.pack!(~T[14:45:53.34])
    end

    test "time without timezone" do
      assert <<0xB1, 0x74, 0xCB, 0x0, 0x0, 0x39, 0x8E, 0xD6, 0xF1, 0xF7, 0x68>> ==
               PackStream.pack!(~T[17:34:45.654321])
    end

    test "Date" do
      assert <<0xB1, 0x44, 0xC9, 0x45, 0x4D>> == PackStream.pack!(~D[2018-07-29])
      assert <<0xB1, 0x44, 0xC9, 0xB6, 0xA0>> == PackStream.pack!(~D[1918-07-29])
      assert <<0xB1, 0x44, _::binary>> = PackStream.pack!(~D[2013-05-06])
    end

    test "local datetime" do
      assert <<0xB2, 0x64, 0xCA, 0x5A, 0xC6, 0x17, 0xB8, 0xCA, 0x27, 0x0, 0x25, 0x68>> ==
               PackStream.pack!(~N[2018-04-05 12:34:00.654321])
    end

    test "time with timezone" do
      ttz = TimeWithTZOffset.create(~T[12:45:30.250000], 3600)

      assert <<0xB2, 0x54, 0xCB, 0x0, 0x0, 0x29, 0xC5, 0xF8, 0x3C, 0x56, 0x80, 0xC9, 0xE, 0x10>> ==
               PackStream.pack!(ttz)
    end

    test "datetime with timezone offset" do
      dt = DateTimeWithTZOffset.create(~N[2016-05-24 13:26:08.654321], 7200)

      assert <<0xB3, 0x46, 0xCA, 0x57, 0x44, 0x56, 0x70, 0xCA, 0x27, 0x0, 0x25, 0x68, 0xC9, 0x1C,
               0x20>> == PackStream.pack!(dt)
    end

    test "datetime with timezone id" do
      dt = TypesHelper.datetime_with_micro(~N[2016-05-24 13:26:08.654321], "Europe/Berlin")

      assert <<0xB3, 0x66, 0xCA, 0x57, 0x44, 0x56, 0x70, 0xCA, 0x27, 0x0, 0x25, 0x68, 0x8D, 0x45,
               0x75, 0x72, 0x6F, 0x70, 0x65, 0x2F, 0x42, 0x65, 0x72, 0x6C, 0x69,
               0x6E>> ==
               PackStream.pack!(dt)
    end

    test "duration with all values" do
      duration = %Duration{
        years: 1,
        months: 3,
        weeks: 2,
        days: 20,
        hours: 2,
        minutes: 32,
        seconds: 54,
        nanoseconds: 5550
      }

      assert <<0xB4, 0x45, 0xF, 0x22, 0xC9, 0x23, 0xD6, 0xC9, 0x15, 0xAE>> ==
               PackStream.pack!(duration)
    end
  end

  describe "Encode spatial types:" do
    @describetag :core

    test "cartesian point 2D" do
      assert <<0xB3, 0x58, 0xC9, 0x1C, 0x23, 0xC1, 0x40, 0x44, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xC1,
               0x40, 0x46, 0x80, 0x0, 0x0, 0x0, 0x0,
               0x0>> =
               PackStream.pack!(Point.create(:cartesian, 40, 45))
    end

    test "geographic point 2D" do
      assert <<0xB3, 0x58, 0xC9, 0x10, 0xE6, 0xC1, 0x40, 0x44, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xC1,
               0x40, 0x46, 0x80, 0x0, 0x0, 0x0, 0x0,
               0x0>> =
               PackStream.pack!(Point.create(:wgs_84, 40, 45))
    end

    test "cartesian point 3D" do
      assert <<0xB4, 0x59, 0xC9, 0x23, 0xC5, 0xC1, 0x40, 0x44, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xC1,
               0x40, 0x46, 0x80, 0x0, 0x0, 0x0, 0x0, 0x0, 0xC1, 0x40, 0x62, 0xC0, 0x0, 0x0, 0x0,
               0x0,
               0x0>> =
               PackStream.pack!(Point.create(:cartesian, 40, 45, 150))
    end

    test "geographic point 3D" do
      assert <<0xB4, 0x59, 0xC9, 0x13, 0x73, 0xC1, 0x40, 0x44, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xC1,
               0x40, 0x46, 0x80, 0x0, 0x0, 0x0, 0x0, 0x0, 0xC1, 0x40, 0x62, 0xC0, 0x0, 0x0, 0x0,
               0x0,
               0x0>> =
               PackStream.pack!(Point.create(:wgs_84, 40, 45, 150))
    end
  end

  describe "Decode data types" do
    @describetag :core

    test "decode a nil" do
      assert PackStream.unpack!(<<0xC0>>) == [nil]
    end

    test "decodes boolean" do
      assert PackStream.unpack!(<<0xC3>>) == [true]
      assert PackStream.unpack!(<<0xC2>>) == [false]
    end

    test "decodes floats" do
      positive = <<0xC1, 0x3F, 0xF1, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9A>>
      negative = <<0xC1, 0xBF, 0xF1, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9A>>

      assert PackStream.unpack!(positive) == [1.1]
      assert PackStream.unpack!(negative) == [-1.1]

      assert [7.7] == PackStream.unpack!(<<0xC1, 0x40, 0x1E, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCD>>)
    end

    test "decodes strings" do
      longstr =
        <<0xD0, 0x1A, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C,
          0x6D, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A>>

      specialcharstr =
        <<0xD0, 0x18, 0x45, 0x6E, 0x20, 0xC3, 0xA5, 0x20, 0x66, 0x6C, 0xC3, 0xB6, 0x74, 0x20,
          0xC3, 0xB6, 0x76, 0x65, 0x72, 0x20, 0xC3, 0xA4, 0x6E, 0x67, 0x65, 0x6E>>

      long_32 = <<210, 0, 1, 1, 208>> <> String.duplicate("a", 66_000)

      assert PackStream.unpack!(<<0x80>>) == [""]
      assert PackStream.unpack!(<<0x81, 0x61>>) == ["a"]
      assert PackStream.unpack!(longstr) == ["abcdefghijklmnopqrstuvwxyz"]
      assert PackStream.unpack!(specialcharstr) == ["En å flöt över ängen"]
      assert PackStream.unpack!(long_32) == [String.duplicate("a", 66_000)]

      assert ["hello"] == PackStream.unpack!(<<0x85, 0x68, 0x65, 0x6C, 0x6C, 0x6F>>)
    end

    test "decodes lists" do
      assert PackStream.unpack!(<<0x90>>) == [[]]
      assert PackStream.unpack!(<<0x93, 0x01, 0x02, 0x03>>) == [[1, 2, 3]]

      assert [[]] == PackStream.unpack!(<<0x90>>)
      assert [[2, 4]] == PackStream.unpack!(<<0x92, 0x2, 0x4>>)

      list_8 =
        <<0xD4, 16::8>> <> (1..16 |> Enum.map(&PackStream.pack!(&1)) |> Enum.join())

      assert PackStream.unpack!(list_8) == [1..16 |> Enum.to_list()]

      list_16 =
        <<0xD5, 256::16>> <> (1..256 |> Enum.map(&PackStream.pack!(&1)) |> Enum.join())

      assert PackStream.unpack!(list_16) == [1..256 |> Enum.to_list()]

      list_32 =
        <<0xD6, 66_000::32>> <>
          (1..66_000 |> Enum.map(&PackStream.pack!(&1)) |> Enum.join())

      assert PackStream.unpack!(list_32) == [1..66_000 |> Enum.to_list()]

      ending_0_list = <<0x93, 0x91, 0x1, 0x92, 0x2, 0x0, 0x0>>
      assert PackStream.unpack!(ending_0_list) == [[[1], [2, 0], 0]]
    end

    test "decodes maps" do
      assert PackStream.unpack!(<<0xA0>>) == [%{}]
      assert PackStream.unpack!(<<0xA1, 0x81, 0x61, 0x01>>) == [%{"a" => 1}]
      assert PackStream.unpack!(<<0xAB, 0x81, 0x61, 0x01>>) == [%{"a" => 1}]

      map_8 =
        <<0xD8, 16::8>> <>
          (1..16
           |> Enum.map(fn i ->
             :erlang.iolist_to_binary(PackStream.pack!("#{i}")) <> <<1>>
           end)
           |> Enum.join())

      assert PackStream.unpack!(map_8) |> List.first() |> map_size == 16

      map_16 =
        <<0xD9, 256::16>> <>
          (1..256
           |> Enum.map(fn i ->
             :erlang.iolist_to_binary(PackStream.pack!("#{i}")) <> <<1>>
           end)
           |> Enum.join())

      assert PackStream.unpack!(map_16) |> List.first() |> map_size == 256

      map_32 =
        <<0xDA, 66_000::32>> <>
          (1..66_000
           |> Enum.map(fn i ->
             :erlang.iolist_to_binary(PackStream.pack!("#{i}")) <> <<1>>
           end)
           |> Enum.join())

      assert PackStream.unpack!(map_32) |> List.first() |> map_size == 66_000
    end

    test "decodes integers" do
      assert PackStream.unpack!(<<0x2A>>) == [42]
      assert PackStream.unpack!(<<0xC8, 0x2A>>) == [42]
      assert PackStream.unpack!(<<0xC9, 0, 0x2A>>) == [42]
      assert PackStream.unpack!(<<0xCA, 0, 0, 0, 0x2A>>) == [42]
      assert PackStream.unpack!(<<0xCB, 0, 0, 0, 0, 0, 0, 0, 0x2A>>) == [42]
    end

    test "decodes negative integers" do
      assert PackStream.unpack!(<<0xC8, 0xD6>>) == [-42]
    end

    test "decodes Node" do
      node =
        <<0x91, 0xB3, 0x4E, 0x11, 0x91, 0x86, 0x50, 0x65, 0x72, 0x73, 0x6F, 0x6E, 0xA2, 0x84,
          0x6E, 0x61, 0x6D, 0x65, 0xD0, 0x10, 0x50, 0x61, 0x74, 0x72, 0x69, 0x63, 0x6B, 0x20,
          0x52, 0x6F, 0x74, 0x68, 0x66, 0x75, 0x73, 0x73, 0x89, 0x62, 0x6F, 0x6C, 0x74, 0x5F,
          0x73, 0x69, 0x70, 0x73, 0xC3>>

      assert [
               [
                 %Boltx.Types.Node{
                   id: 17,
                   labels: ["Person"],
                   properties: %{"bolt_sips" => true, "name" => "Patrick Rothfuss"}
                 }
               ]
             ] == PackStream.unpack!(node)
    end

    test "decodes Relationship" do
      rel = <<0x91, 0xB5, 0x52, 0x50, 0x46, 0x43, 0x85, 0x57, 0x52, 0x4F, 0x54, 0x45, 0xA0>>

      assert [
               [
                 %Boltx.Types.Relationship{
                   end: 67,
                   id: 80,
                   properties: %{},
                   start: 70,
                   type: "WROTE"
                 }
               ]
             ] = PackStream.unpack!(rel)
    end

    test "decodes path" do
      path =
        <<0x91, 0xB3, 0x50, 0x92, 0xB3, 0x4E, 0x30, 0x90, 0xA2, 0x84, 0x6E, 0x61, 0x6D, 0x65,
          0x85, 0x41, 0x6C, 0x69, 0x63, 0x65, 0x89, 0x62, 0x6F, 0x6C, 0x74, 0x5F, 0x73, 0x69,
          0x70, 0x73, 0xC3, 0xB3, 0x4E, 0x38, 0x90, 0xA2, 0x84, 0x6E, 0x61, 0x6D, 0x65, 0x83,
          0x42, 0x6F, 0x62, 0x89, 0x62, 0x6F, 0x6C, 0x74, 0x5F, 0x73, 0x69, 0x70, 0x73, 0xC3,
          0x91, 0xB3, 0x72, 0x13, 0x85, 0x4B, 0x4E, 0x4F, 0x57, 0x53, 0xA0, 0x92, 0x1, 0x1>>

      [
        [
          %Boltx.Types.Path{
            nodes: [
              %Boltx.Types.Node{
                id: 48,
                labels: [],
                properties: %{"bolt_sips" => true, "name" => "Alice"}
              },
              %Boltx.Types.Node{
                id: 56,
                labels: [],
                properties: %{"bolt_sips" => true, "name" => "Bob"}
              }
            ],
            relationships: [
              %Boltx.Types.UnboundRelationship{
                id: 19,
                properties: %{},
                type: "KNOWS"
              }
            ],
            sequence: [1, 1]
          }
        ]
      ] = PackStream.unpack!(path)
    end
  end

  describe "Decode temporal data:" do
    @describetag :core

    test "date post 1970-01-01" do
      assert [~D[2018-07-29]] == PackStream.unpack!({0x44, <<0xC9, 0x45, 0x4D>>, 1})
    end

    test "date pre 1970-01-01" do
      assert [~D[1918-07-29]] == PackStream.unpack!({0x44, <<0xC9, 0xB6, 0xA0>>, 1})
    end

    test "Local Date" do
      assert [~D[2013-12-15]] == PackStream.unpack!(<<0xB1, 0x44, 0xC9, 0x3E, 0xB6>>)
    end

    test "local time" do
      assert [~T[13:25:01.952456]] ==
               PackStream.unpack!(
                 {0x74, <<0xCB, 0x0, 0x0, 0x2B, 0xEE, 0x2C, 0xB7, 0xD5, 0x40>>, 1}
               )

      assert [~T[09:34:23.654321]] ==
               PackStream.unpack!(
                 <<0xB1, 0x74, 0xCB, 0x0, 0x0, 0x1F, 0x58, 0x31, 0xDF, 0x9B, 0x68>>
               )
    end

    test "local datetime" do
      assert [~N[2014-11-30 16:15:01.435432]] ==
               PackStream.unpack!(
                 {0x64, <<0xCA, 0x54, 0x7B, 0x42, 0x85, 0xCA, 0x19, 0xF4, 0x2A, 0x40>>, 2}
               )

      assert [~N[2018-04-05 12:34:00.654321]] ==
               PackStream.unpack!(
                 <<0xB2, 0x64, 0xCA, 0x5A, 0xC6, 0x17, 0xB8, 0xCA, 0x27, 0x0, 0x25, 0x68>>
               )
    end

    test "Time with timezone offzet" do
      assert [%TimeWithTZOffset{time: ~T[04:45:32.123456], timezone_offset: 7200}] ==
               PackStream.unpack!(
                 {0x54, <<0xCB, 0x0, 0x0, 0xF, 0x94, 0xE2, 0x22, 0x2, 0x0, 0xC9, 0x1C, 0x20>>, 2}
               )

      ttz = TimeWithTZOffset.create(~T[12:45:30.654321], 3600)

      assert [ttz] ==
               PackStream.unpack!(
                 <<0xB2, 0x54, 0xCB, 0x0, 0x0, 0x29, 0xC6, 0x10, 0x55, 0xC9, 0x68, 0xC9, 0xE,
                   0x10>>
               )
    end

    test "Datetime with zone id" do
      dt =
        Boltx.TypesHelper.datetime_with_micro(~N[1998-03-18 06:25:12.123456], "Europe/Paris")

      assert [dt] ==
               PackStream.unpack!(
                 {0x66,
                  <<0xCA, 0x35, 0xF, 0x68, 0xC8, 0xCA, 0x7, 0x5B, 0xCA, 0x0, 0x8C, 0x45, 0x75,
                    0x72, 0x6F, 0x70, 0x65, 0x2F, 0x50, 0x61, 0x72, 0x69, 0x73>>, 3}
               )

      dt =
        Boltx.TypesHelper.datetime_with_micro(
          ~N[2016-05-24 13:26:08.654321],
          "Europe/Berlin"
        )

      assert [dt] ==
               PackStream.unpack!(
                 <<0xB3, 0x66, 0xCA, 0x57, 0x44, 0x56, 0x70, 0xCA, 0x27, 0x0, 0x25, 0x68, 0x8D,
                   0x45, 0x75, 0x72, 0x6F, 0x70, 0x65, 0x2F, 0x42, 0x65, 0x72, 0x6C, 0x69, 0x6E>>
               )
    end

    test "Datetime with zone offset" do
      assert [
               %DateTimeWithTZOffset{
                 naive_datetime: ~N[1998-03-18 06:25:12.123456],
                 timezone_offset: 7200
               }
             ] ==
               PackStream.unpack!(
                 {0x46,
                  <<0xCA, 0x35, 0xF, 0x68, 0xC8, 0xCA, 0x7, 0x5B, 0xCA, 0x0, 0xC9, 0x1C, 0x20>>,
                  3}
               )

      assert [
               %DateTimeWithTZOffset{
                 naive_datetime: ~N[2016-05-24 13:26:08.654321],
                 timezone_offset: 7200
               }
             ] =
               PackStream.unpack!(
                 <<0xB3, 0x46, 0xCA, 0x57, 0x44, 0x56, 0x70, 0xCA, 0x27, 0x0, 0x25, 0x68, 0xC9,
                   0x1C, 0x20>>
               )
    end

    test "Duration" do
      assert [
               %Duration{
                 days: 11,
                 hours: 15,
                 minutes: 0,
                 months: 8,
                 nanoseconds: 5550,
                 seconds: 21,
                 weeks: 0,
                 years: 3
               }
             ] ==
               PackStream.unpack!(
                 {0x45, <<0x2C, 0xB, 0xCA, 0x0, 0x0, 0xD3, 0x5, 0xC9, 0x15, 0xAE>>, 4}
               )

      assert [
               %Duration{
                 years: 1,
                 months: 3,
                 days: 34,
                 hours: 2,
                 minutes: 32,
                 seconds: 54,
                 nanoseconds: 5550
               }
             ] ==
               PackStream.unpack!(<<0xB4, 0x45, 0xF, 0x22, 0xC9, 0x23, 0xD6, 0xC9, 0x15, 0xAE>>)
    end

    test "Point2D (cartesian)" do
      assert [
               %Point{
                 crs: "cartesian",
                 height: nil,
                 latitude: nil,
                 longitude: nil,
                 srid: 7203,
                 x: 45.0003,
                 y: 34.5434,
                 z: nil
               }
             ] ==
               PackStream.unpack!(
                 {0x58,
                  <<0xC9, 0x1C, 0x23, 0xC1, 0x40, 0x46, 0x80, 0x9, 0xD4, 0x95, 0x18, 0x2B, 0xC1,
                    0x40, 0x41, 0x45, 0x8E, 0x21, 0x96, 0x52, 0xBD>>, 3}
               )

      assert [
               %Point{
                 crs: "cartesian",
                 height: nil,
                 latitude: nil,
                 longitude: nil,
                 srid: 7203,
                 x: 40.0,
                 y: 45.0,
                 z: nil
               }
             ] =
               PackStream.unpack!(
                 <<0xB3, 0x58, 0xC9, 0x1C, 0x23, 0xC1, 0x40, 0x44, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                   0xC1, 0x40, 0x46, 0x80, 0x0, 0x0, 0x0, 0x0, 0x0>>
               )
    end

    test "Point2D (geographic)" do
      assert [
               %Point{
                 crs: "wgs-84",
                 height: nil,
                 latitude: 15.00943,
                 longitude: 20.45352,
                 srid: 4326,
                 x: 20.45352,
                 y: 15.00943,
                 z: nil
               }
             ] ==
               PackStream.unpack!(
                 {0x58,
                  <<0xC9, 0x10, 0xE6, 0xC1, 0x40, 0x34, 0x74, 0x19, 0xE3, 0x0, 0x14, 0xF9, 0xC1,
                    0x40, 0x2E, 0x4, 0xD4, 0x2, 0x4B, 0x33, 0xDB>>, 3}
               )

      assert [
               %Point{
                 crs: "wgs-84",
                 height: nil,
                 latitude: 45.0,
                 longitude: 40.0,
                 srid: 4326,
                 x: 40.0,
                 y: 45.0,
                 z: nil
               }
             ] =
               PackStream.unpack!(
                 <<0xB3, 0x58, 0xC9, 0x10, 0xE6, 0xC1, 0x40, 0x44, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                   0xC1, 0x40, 0x46, 0x80, 0x0, 0x0, 0x0, 0x0, 0x0>>
               )
    end

    test "Point3D (cartesian)" do
      assert [
               %Point{
                 crs: "cartesian-3d",
                 height: nil,
                 latitude: nil,
                 longitude: nil,
                 srid: 9157,
                 x: 48.8354,
                 y: 12.72468,
                 z: 50.004
               }
             ] ==
               PackStream.unpack!(
                 {0x59,
                  <<0xC9, 0x23, 0xC5, 0xC1, 0x40, 0x48, 0x6A, 0xEE, 0x63, 0x1F, 0x8A, 0x9, 0xC1,
                    0x40, 0x29, 0x73, 0x9, 0x41, 0xC8, 0x21, 0x6C, 0xC1, 0x40, 0x49, 0x0, 0x83,
                    0x12, 0x6E, 0x97, 0x8D>>, 4}
               )

      assert [
               %Point{
                 crs: "cartesian-3d",
                 height: nil,
                 latitude: nil,
                 longitude: nil,
                 srid: 9157,
                 x: 40.0,
                 y: 45.0,
                 z: 150.0
               }
             ] =
               PackStream.unpack!(
                 <<0xB4, 0x59, 0xC9, 0x23, 0xC5, 0xC1, 0x40, 0x44, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                   0xC1, 0x40, 0x46, 0x80, 0x0, 0x0, 0x0, 0x0, 0x0, 0xC1, 0x40, 0x62, 0xC0, 0x0,
                   0x0, 0x0, 0x0, 0x0>>
               )
    end

    test "Point3D (geographic)" do
      assert [
               %Point{
                 crs: "wgs-84-3d",
                 height: -123.0004,
                 latitude: 70.40958,
                 longitude: 13.39538,
                 srid: 4979,
                 x: 13.39538,
                 y: 70.40958,
                 z: -123.0004
               }
             ] ==
               PackStream.unpack!(
                 {0x59,
                  <<0xC9, 0x13, 0x73, 0xC1, 0x40, 0x2A, 0xCA, 0x6F, 0x3F, 0x52, 0xFC, 0x26, 0xC1,
                    0x40, 0x51, 0x9A, 0x36, 0x8F, 0x8, 0x46, 0x20, 0xC1, 0xC0, 0x5E, 0xC0, 0x6,
                    0x8D, 0xB8, 0xBA, 0xC7>>, 4}
               )

      assert [
               %Point{
                 crs: "wgs-84-3d",
                 height: 150.0,
                 latitude: 45.0,
                 longitude: 40.0,
                 srid: 4979,
                 x: 40.0,
                 y: 45.0,
                 z: 150.0
               }
             ] =
               PackStream.unpack!(
                 <<0xB4, 0x59, 0xC9, 0x13, 0x73, 0xC1, 0x40, 0x44, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                   0xC1, 0x40, 0x46, 0x80, 0x0, 0x0, 0x0, 0x0, 0x0, 0xC1, 0x40, 0x62, 0xC0, 0x0,
                   0x0, 0x0, 0x0, 0x0>>
               )
    end
  end
end
