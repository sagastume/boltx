defmodule Boltx.BoltProtocol.Message.GoodbyeMessageTest do
  use ExUnit.Case, async: true

  alias Boltx.BoltProtocol.Message.GoodbyeMessage

  describe "GoodbyeMessage.encode/1" do
    @tag :core
    test "coding with version >= 3 of bolt" do
      bolt_version = 3.0

      assert <<0, 2, 176, 2, 0, 0>> == GoodbyeMessage.encode(bolt_version)
    end

    @tag :core
    test "coding with version < 3 of bolt" do
      bolt_version = 1.0

      assert {:error,
              %Boltx.Error{
                module: Boltx.BoltProtocol.Message.GoodbyeMessage,
                bolt: %{code: :unsupported_message_version}
              }} = GoodbyeMessage.encode(bolt_version)
    end

    @tag :core
    test "coding with version integer" do
      bolt_version = 1

      assert {:error,
              %Boltx.Error{
                module: Boltx.BoltProtocol.Message.GoodbyeMessage,
                bolt: %{code: :unsupported_message_version}
              }} = GoodbyeMessage.encode(bolt_version)
    end
  end
end
