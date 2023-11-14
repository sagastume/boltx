defmodule Boltx.Internals.PackStream.Message do
  @moduledoc false

  # Manage the message encoding and decoding.
  #
  # Message encoding / decoding is the first step of encoding / decoding.
  # The next step is the message data encoding /decoding (which is handled by packstream.ex)

  alias Boltx.Internals.PackStream.Message.Encoder
  alias Boltx.Internals.PackStream.Message.Decoder

  @type in_signature :: :failure | :ignored | :record | :success
  @type out_signature ::
          :ack_failure
          | :begin
          | :commit
          | :discard_all
          | :goodbye
          | :hello
          | :init
          | :pull_all
          | :reset
          | :rollback
          | :run
  @type raw :: {out_signature, list()}
  @type decoded :: {in_signature(), any()}
  @type encoded :: <<_::16, _::_*8>>

  @doc """
  Encode a message depending on its type
  """
  @spec encode({Boltx.Internals.PackStream.Message.out_signature(), list()}, integer()) ::
          Boltx.Internals.PackStream.Message.encoded()
  def encode(message, bolt_version) do
    Encoder.encode(message, bolt_version)
  end

  @doc """
  Decode a message
  """
  @spec decode(Boltx.Internals.PackStream.Message.encoded(), integer()) ::
          Boltx.Internals.PackStream.Message.decoded()
  def decode(message, bolt_version) do
    Decoder.decode(message, bolt_version)
  end
end
