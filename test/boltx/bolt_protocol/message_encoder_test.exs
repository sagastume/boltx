defmodule Boltx.BoltProtocol.Message.MessageEncoderTest do
  use ExUnit.Case, async: true

  alias Boltx.BoltProtocol.Message.{
    AckFailureMessage,
    InitMessage,
    BeginMessage,
    CommitMessage,
    DiscardMessage,
    GoodbyeMessage,
    HelloMessage,
    RollbackMessage,
    PullMessage,
    ResetMessage,
    RunMessage
  }

  @moduletag :core

  defmodule TestUser do
    defstruct name: "", boltx: true
  end

  describe "Encode ACK_FAILURE" do
    test "without params" do
      assert <<0x0, 0x2, 0xB0, 0xE, 0x0, 0x0>> == AckFailureMessage.encode(1.0)
    end
  end

  describe "Encode Init" do
    test "without params" do
      assert <<0x0, _, 0xB2, 0x1, _::binary>> = InitMessage.encode(1.0, [])
    end

    test "with params" do
      assert <<0x0, _, 0xB2, 0x1, _::binary>> =
               InitMessage.encode(1.0, auth: [username: "hello", password: "hellopw"])
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

  describe "Encode BEGIN" do
    test "without params" do
      assert <<_, _, _, 0x11, _::binary>> = BeginMessage.encode(3.0, %{})
    end

    test "with params" do
      assert <<_, _, _, 0x11, _::binary>> = BeginMessage.encode(3.0, %{mode: "w"})
    end
  end

  describe "Encode COMMIT" do
    test "without params" do
      assert <<0x0, 0x2, 0xB0, 0x12, 0x0, 0x0>> == CommitMessage.encode(3.0)
    end
  end

  describe "Encode DISCARD" do
    test "without params" do
      assert <<0x0, 0x2, 0xB0, 0x2F, 0x0, 0x0>> = DiscardMessage.encode(2.0, %{})
    end
  end

  describe "Encode GOODBYE" do
    test "without params" do
      assert assert <<_, _, _, 0x02, _::binary>> = GoodbyeMessage.encode(3.0)
    end
  end

  describe "Encode ROLLBACK" do
    test "without params" do
      assert <<0x0, 0x2, 0xB0, 0x13, 0x0, 0x0>> = RollbackMessage.encode(3.0)
    end
  end

  describe "Encode PULL" do
    test "without params" do
      assert <<0x0, 0x2, 0xB0, 0x3F, 0x0, 0x0>> = PullMessage.encode(3.0, %{})
    end
  end

  describe "Encode RESET" do
    test "without params" do
      assert <<0x0, 0x2, 0xB0, 0xF, 0x0, 0x0>> == ResetMessage.encode(3.0)
    end
  end

  describe "Encode RUN" do
    test "without params" do
      assert <<0, 55, 179, 16, 143, 82, 69, 84, 85, 82, 78, 32, 49, 32, 65, 83, 32, 110, 117, 109,
               160, 164, 132, 109, 111, 100, 101, 129, 119, 137, 98, 111, 111, 107, 109, 97, 114,
               107, 115, 144, 130, 100, 98, 192, 139, 116, 120, 95, 109, 101, 116, 97, 100, 97,
               116, 97, 192, 0, 0>> == RunMessage.encode(3.0, "RETURN 1 AS num", %{}, %{})
    end

    test "with params" do
      assert <<0, 64, 179, 16, 208, 18, 82, 69, 84, 85, 82, 78, 32, 36, 110, 117, 109, 32, 65, 83,
               32, 110, 117, 109, 161, 131, 110, 117, 109, 5, 164, 132, 109, 111, 100, 101, 129,
               119, 137, 98, 111, 111, 107, 109, 97, 114, 107, 115, 144, 130, 100, 98, 192, 139,
               116, 120, 95, 109, 101, 116, 97, 100, 97, 116, 97, 192, 0,
               0>> == RunMessage.encode(3.0, "RETURN $num AS num", %{num: 5}, %{})
    end

    test "with parameters encoding a structure" do
      query = "CREATE (n:User $props)"
      params = %{props: %TestUser{boltx: true, name: "Strut"}}

      assert <<0, 88, 179, 16, 208, 22, 67, 82, 69, 65, 84, 69, 32, 40, 110, 58, 85, 115, 101,
               114, 32, 36, 112, 114, 111, 112, 115, 41, 161, 133, 112, 114, 111, 112, 115, 162,
               132, 110, 97, 109, 101, 133, 83, 116, 114, 117, 116, 133, 98, 111, 108, 116, 120,
               195, 164, 132, 109, 111, 100, 101, 129, 119, 137, 98, 111, 111, 107, 109, 97, 114,
               107, 115, 144, 130, 100, 98, 192, 139, 116, 120, 95, 109, 101, 116, 97, 100, 97,
               116, 97, 192, 0,
               0>> ==
               RunMessage.encode(3.0, query, params, %{})
    end
  end
end
