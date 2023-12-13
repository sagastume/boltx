defmodule Boltx.Internals.PackStream.Message.EncoderV1 do
  @moduledoc false
  use Boltx.Internals.PackStream.Message.Signatures
  alias Boltx.Internals.PackStream.Message.Encoder

  @doc """
  Encode INIT message without auth token
  """
  @spec encode({Boltx.Internals.PackStream.Message.out_signature(), list()}, integer()) ::
          Boltx.Internals.PackStream.Message.encoded() | {:error, :not_implemented}
  def encode(data, bolt_version) do
    Encoder.encode(data, bolt_version)
  end
end
