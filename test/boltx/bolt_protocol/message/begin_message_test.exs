defmodule Boltx.BoltProtocol.Message.BeginMessageTest do
  use ExUnit.Case, async: true

  alias Boltx.BoltProtocol.Message.BeginMessage

  describe "BeginMessage.encode/2" do
    @tag :core
    test "coding without parameters" do
      bolt_version = 3.0

      assert <<0, 3, 177, 17, 160, 0, 0>> == BeginMessage.encode(bolt_version, %{})
    end

    @tag :core
    test "coding with parameters" do
      bolt_version = 3.0

      assert <<0, 38, 177, 17, 164, 132, 109, 111, 100, 101, 129, 119, 137, 98, 111, 111, 107,
               109, 97, 114, 107, 115, 144, 130, 100, 98, 192, 139, 116, 120, 95, 109, 101, 116,
               97, 100, 97, 116, 97, 192, 0,
               0>> ==
               BeginMessage.encode(bolt_version, %{
                 bookmarks: [],
                 mode: "w",
                 db: nil,
                 tx_metadata: nil
               })
    end

    @tag :core
    test "coding with version < 3 of bolt" do
      bolt_version = 2.0

      assert {:error,
              %Boltx.Error{
                module: Boltx.BoltProtocol.Message.BeginMessage,
                bolt: %{code: :unsupported_message_version}
              }} = BeginMessage.encode(bolt_version, %{})
    end
  end
end
