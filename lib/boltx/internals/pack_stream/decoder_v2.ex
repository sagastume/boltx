defmodule Boltx.Internals.PackStream.DecoderV2 do
  @moduledoc false
  _module_doc = """
  Bolt V2 has specification for decoding:
  - Temporal types:
    - Local Date
    - Local Time
    - Local DateTime
    - Time with Timezone Offset
    - DateTime with Timezone Id
    - DateTime with Timezone Offset
    - Duration
  - Spatial types:
    - Point2D
    - Point3D

  For documentation about those typs representation in Bolt binary,
  please see `Boltx.Internals.PackStream.EncoderV2`.

  Functions from this module are not meant to be used directly.
  Use `Decoder.decode(data, bolt_version)` for all decoding purposes.
  """

  use Boltx.Internals.PackStream.Markers
  alias Boltx.Internals.PackStream.Decoder

  # Local Date
  @spec decode({integer(), binary(), integer()}, integer()) :: list() | {:error, :not_implemented}
  def decode(data, bolt_version), do: Decoder.decode(data, bolt_version)

end
