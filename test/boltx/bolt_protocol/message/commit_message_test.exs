defmodule Boltx.BoltProtocol.Message.CommitMessageTest do
  use ExUnit.Case, async: true

  alias Boltx.BoltProtocol.Message.CommitMessage

  describe "CommitMessage.encode/1" do
    @tag :core
    test "coding with version >= 3 of bolt" do
      bolt_version = 3.0

      assert <<0, 2, 176, 18, 0, 0>> == CommitMessage.encode(bolt_version)
    end

    @tag :core
    test "coding with version < 3 of bolt" do
      bolt_version = 1.0

      assert {:error,
              %Boltx.Error{
                module: Boltx.BoltProtocol.Message.CommitMessage,
                bolt: %{code: :unsupported_message_version}
              }} = CommitMessage.encode(bolt_version)
    end

    @tag :core
    test "coding with version integer" do
      bolt_version = 1

      assert {:error,
              %Boltx.Error{
                module: Boltx.BoltProtocol.Message.CommitMessage,
                bolt: %{code: :unsupported_message_version}
              }} = CommitMessage.encode(bolt_version)
    end
  end
end
