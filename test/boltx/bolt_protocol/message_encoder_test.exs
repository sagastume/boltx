defmodule Boltx.BoltProtocol.Message.AckFailureMessageTest do
  use ExUnit.Case, async: true

  alias Boltx.BoltProtocol.Message.{
    AckFailureMessage,
    HelloMessage
  }

  @moduletag :core

  describe "Encode ACK_FAILURE" do
    test "without params" do
      assert <<0x0, 0x2, 0xB0, 0xE, 0x0, 0x0>> == AckFailureMessage.encode(1.0)
    end
  end

  describe "Encode HELLO" do
    test "without params" do
      assert <<0x0, _, 0xB1, 0x1, _::binary>> = HelloMessage.encode(3.0, [])
    end

    test "with params" do
      assert <<0x0, _, 0xB1, 0x1, _::binary>> =
               HelloMessage.encode(3.0, user_agent: "user_agent_test")
    end

    test "with auth" do
      assert <<_, _, _, 0x01, _::binary>> =
               HelloMessage.encode(3.0, auth: [username: "hello", password: "hellopw"])
    end
  end
end
