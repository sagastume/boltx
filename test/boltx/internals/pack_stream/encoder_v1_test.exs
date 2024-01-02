defmodule Boltx.Internals.PackStream.EncoderV1Test do
  use ExUnit.Case, async: true

  alias Boltx.Internals.PackStream.EncoderV1

  @moduletag :legacy

  defmodule TestStruct do
    defstruct foo: "bar"
  end

  doctest Boltx.Internals.PackStream.EncoderV1

  test "encodes a struct" do
    assert <<0xB2, 0x1, 0x85, 0x66, 0x69, 0x72, 0x73, 0x74, 0x86, 0x73, 0x65, 0x63, 0x6F, 0x6E,
             0x64>> ==
             :erlang.iolist_to_binary(EncoderV1.encode_struct({0x01, ["first", "second"]}, 1))

    assert <<0xDC, 0x6F, _::binary>> =
             :erlang.iolist_to_binary(EncoderV1.encode_struct({0x01, Enum.into(1..111, [])}, 1))

    assert <<0xDD, 0x1, 0x4D, _::binary>> =
             :erlang.iolist_to_binary(EncoderV1.encode_struct({0x01, Enum.into(1..333, [])}, 1))

    # Test for a fixed bug
    assert <<0xB1, 0x1, 0xA1, 0x83, 0x66, 0x6F, 0x6F, 0x83, 0x62, 0x61, 0x72>> ==
             :erlang.iolist_to_binary(EncoderV1.encode_struct({0x01, [%TestStruct{}]}, 1))
  end
end
