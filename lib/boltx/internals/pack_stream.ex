defmodule Boltx.Internals.PackStream do
  @moduledoc false

  # The PackStream implementation for Bolt.
  #
  # This module defines a decode function, that will take a binary stream of data
  # and recursively turn it into a list of Elixir data types.
  #
  # It further defines a function for encoding Elixir data types into a binary
  # stream, using the Boltx.Internals.PackStream.Encoder protocol.

  @type value :: <<_::8, _::_*8>>

  @doc """
  Encodes a list of items into their binary representation.

  As developers tend to be lazy, single objects may be passed.

  ## Examples

      iex> Boltx.Internals.PackStream.encode "hello world"
      <<0x8B, 0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x77, 0x6F, 0x72, 0x6C, 0x64>>
  """
  @spec encode(any(), integer()) :: Boltx.Internals.PackStream.value() | <<_::16, _::_*8>>
  def encode(item, bolt_version) do
    Boltx.Internals.PackStream.Encoder.encode(item, bolt_version)
  end

  @doc """
  Decode data from Bolt binary format to Elixir type

  ## Example

      iex> Boltx.Internals.PackStream.decode(<<0xC3>>)
      [true]
  """
  @spec decode(binary(), integer()) :: list()
  def decode(data, bolt_version) do
    Boltx.Internals.PackStream.Decoder.decode(data, bolt_version)
  end
end
