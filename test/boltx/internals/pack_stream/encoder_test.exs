defmodule Boltx.Internals.PackStream.EncoderTest do
  use ExUnit.Case, async: false

  alias Boltx.Internals.PackStream.Encoder
  alias Boltx.Internals.BoltVersionHelper

  @moduletag :legacy

  defmodule TestStruct do
    defstruct foo: "bar"
  end

  describe "Encode common types:" do
    Enum.each(BoltVersionHelper.available_versions(), fn bolt_version ->
      test "raises error when trying to encode with unknown signature (bolt_version: #{bolt_version})" do
        assert_raise Boltx.Internals.PackStreamError, ~r/^unable to encode/i, fn ->
          Encoder.encode({128, []}, unquote(bolt_version))
        end

        assert_raise Boltx.Internals.PackStreamError, ~r/^unable to encode/i, fn ->
          Encoder.encode({-1, []}, unquote(bolt_version))
        end

        assert_raise Boltx.Internals.PackStreamError, ~r/^unable to encode/i, fn ->
          Encoder.encode({"a", []}, unquote(bolt_version))
        end
      end

      test "unkown type (bolt_version: #{bolt_version})" do
        assert_raise Boltx.Internals.PackStreamError, fn ->
          Encoder.encode({:error, "unencodable"}, unquote(bolt_version))
        end
      end
    end)
  end
end
