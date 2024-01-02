defmodule Boltx.Internals.PackStream.DecoderTest do
  use ExUnit.Case, async: true

  alias Boltx.Internals.PackStream.Decoder
  alias Boltx.Internals.PackStreamError
  alias Boltx.Internals.BoltVersionHelper

  @moduletag :legacy

  describe "Decode common types" do
    Enum.each(BoltVersionHelper.available_versions(), fn bolt_version ->
      test "Fails to decode something unknown (bolt_version: #{bolt_version})" do
        assert_raise PackStreamError, fn ->
          Decoder.decode(0xFF, unquote(bolt_version))
        end
      end
    end)
  end
end
