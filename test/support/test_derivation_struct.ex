defmodule Boltx.TestDerivationStruct do
  @derive [{Boltx.PackStream.Packer, fields: [:foo]}]
  defstruct foo: "bar", name: "Hugo Weaving"
end
