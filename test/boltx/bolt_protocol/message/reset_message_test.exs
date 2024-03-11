defmodule Boltx.BoltProtocol.Message.ResetMessageTest do
  use ExUnit.Case, async: true

  alias Boltx.BoltProtocol.Message.ResetMessage

  describe "ResetMessage.encode/1" do
    @tag :core
    test "coding with version >= 3.0 of bolt" do
      bolt_version = 3.0
      assert <<0, 2, 176, 15, 0, 0>> == ResetMessage.encode(bolt_version)
    end

    @tag :core
    test "coding with version <= 2 of bolt" do
      bolt_version = 2.0

      assert {:error,
              %Boltx.Error{
                module: Boltx.BoltProtocol.Message.ResetMessage,
                bolt: %{code: :unsupported_message_version}
              }} = ResetMessage.encode(bolt_version)
    end

    @tag :core
    test "coding with version integer" do
      bolt_version = 1

      assert {:error,
              %Boltx.Error{
                module: Boltx.BoltProtocol.Message.ResetMessage,
                bolt: %{code: :unsupported_message_version}
              }} = ResetMessage.encode(bolt_version)
    end
  end
end
