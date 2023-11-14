defmodule Boltx.Internals.PackStream.DecoderV1 do
  @moduledoc false
  _moduledoc = """
  Bolt V1 can decode:
  - Null
  - Boolean
  - Integer
  - Float
  - String
  - List
  - Map
  - Struct

  Functions from this module are not meant to be used directly.
  Use `Decoder.decode(data, bolt_version)` for all decoding purposes.
  """

  use Boltx.Internals.PackStream.Markers
  alias Boltx.Internals.PackStream.Decoder

  @spec decode(binary() | {integer(), binary(), integer()}, integer()) ::
          list() | {:error, :not_implemented}
  def decode(data, bolt_version), do: Decoder.decode(data, bolt_version)
end
