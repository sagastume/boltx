defmodule Boltx.BoltProtocol.Message.LogoffMessageTest do
  use ExUnit.Case, async: true

  alias Boltx.BoltProtocol.Message.LogoffMessage

  describe "LogoffMessage.encode/1" do
    @tag :core
    test "coding with version >= 5.1 of bolt" do
      bolt_version = 5.1

      assert <<0, 2, 176, 107, 0, 0>> == LogoffMessage.encode(bolt_version)
    end

    @tag :core
    test "coding with version <= 2 of bolt" do
      bolt_version = 2.0

      assert {:error,
              %Boltx.Error{
                module: Boltx.BoltProtocol.Message.LogoffMessage,
                bolt: %{code: :unsupported_message_version}
              }} = LogoffMessage.encode(bolt_version)
    end

    @tag :core
    test "coding with version integer" do
      bolt_version = 1

      assert {:error,
              %Boltx.Error{
                module: Boltx.BoltProtocol.Message.LogoffMessage,
                bolt: %{code: :unsupported_message_version}
              }} = LogoffMessage.encode(bolt_version)
    end
  end
end
