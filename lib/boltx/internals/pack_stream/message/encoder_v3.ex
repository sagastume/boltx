defmodule Boltx.Internals.PackStream.Message.EncoderV3 do
  @moduledoc false
  use Boltx.Internals.PackStream.Message.Signatures
  alias Boltx.Internals.PackStream.Message.Encoder

  @valid_signatures [
    @begin_signature,
    @commit_signature,
    @discard_all_signature,
    @goodbye_signature,
    @hello_signature,
    @pull_all_signature,
    @reset_signature,
    @rollback_signature,
    @run_signature
  ]

  @doc """
  Return the valid signatures for bolt V1
  """
  @spec valid_signatures() :: [integer()]
  def valid_signatures() do
    @valid_signatures
  end

  @doc """
  Encode HELLO message without auth token
  """
  @spec encode({Boltx.Internals.PackStream.Message.out_signature(), list()}, integer()) ::
          Boltx.Internals.PackStream.Message.encoded()
          | {:error, :not_implemented}
          | {:error, :invalid_message}
  def encode(data, bolt_version) do
    Encoder.encode(data, bolt_version)
  end
end
