defmodule Boltx.BoltProtocol.VersionsTest do
  use ExUnit.Case, async: true

  describe "available_versions/0" do
    @tag core: true
    test "returns a list of available versions" do
      assert Boltx.BoltProtocol.Versions.available_versions() == [
               1.0,
               2.0,
               3.0,
               4.0,
               4.1,
               4.2,
               4.3,
               4.4,
               5.0,
               5.1,
               5.2,
               5.3,
               5.4
             ]
    end
  end

  describe "latest versions" do
    @tag core: true
    test "latest_versions/1" do
      assert Boltx.BoltProtocol.Versions.latest_versions() == [{5, 0..4}, {4, 3..4}, {4, 2}, {4, 1}]
    end
  end

  describe "to_bytes/1" do
    @tag core: true
    test "converts a float version to bytes version" do
      assert Boltx.BoltProtocol.Versions.to_bytes(5.3) == <<0, 0, 3, 5>>
    end

    @tag core: true
    test "converts an integer version to bytes version" do
      assert Boltx.BoltProtocol.Versions.to_bytes(5) == <<0, 0, 0, 5>>
    end

    @tag core: true
    test "converts a {major, minor} version to bytes" do
      assert Boltx.BoltProtocol.Versions.to_bytes({4, 3}) == <<0, 0, 3, 4>>
    end

    @tag core: true
    test "converts a {major, range} version to bytes" do
      assert Boltx.BoltProtocol.Versions.to_bytes({5, 0..4}) == <<0, 4, 4, 5>>
      assert Boltx.BoltProtocol.Versions.to_bytes({4, 1..3}) == <<0, 2, 3, 4>>
    end
  end
end
