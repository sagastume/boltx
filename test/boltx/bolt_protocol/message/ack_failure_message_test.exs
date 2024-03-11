defmodule Boltx.BoltProtocol.Message.AckFailureMessageTest do
  use ExUnit.Case, async: true

  alias Boltx.BoltProtocol.Message.AckFailureMessage

  describe "AckFailureMessage.encode/1" do
    @tag :core
    test "coding with version <= 2 of bolt" do
      bolt_version = 1.0

      assert <<0, 2, 176, 14, 0, 0>> == AckFailureMessage.encode(bolt_version)
    end

    @tag :core
    test "coding with version >= 3 of bolt" do
      bolt_version = 3.0

      assert {:error,
              %Boltx.Error{
                module: Boltx.BoltProtocol.Message.AckFailureMessage,
                bolt: %{code: :unsupported_message_version}
              }} = AckFailureMessage.encode(bolt_version)
    end

    @tag :core
    test "coding with version integer" do
      bolt_version = 1

      assert {:error,
              %Boltx.Error{
                module: Boltx.BoltProtocol.Message.AckFailureMessage,
                bolt: %{code: :unsupported_message_version}
              }} = AckFailureMessage.encode(bolt_version)
    end
  end
end
