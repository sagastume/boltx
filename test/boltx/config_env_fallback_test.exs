defmodule Boltx.ConfigEnvFallbackTest do
  # async: false — these tests mutate global OS environment variables.
  use ExUnit.Case, async: false

  alias Boltx.Client.Config
  alias Boltx.BoltProtocol.Versions

  @bolt_env_vars ~w(BOLT_USER BOLT_PWD BOLT_HOST BOLT_TCP_PORT BOLT_VERSIONS)
  @auth_opts [auth: [username: "optuser", password: "optpass"]]

  # Start every test from a known-clean env and restore the real environment
  # afterwards (delete keys that were originally unset, put back the rest).
  setup do
    originals = Map.new(@bolt_env_vars, fn key -> {key, System.get_env(key)} end)
    Enum.each(@bolt_env_vars, &System.delete_env/1)

    on_exit(fn ->
      Enum.each(originals, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end)

    :ok
  end

  describe "disable_env_fallback" do
    @tag :core
    test "BOLT_USER overrides :auth by default, is ignored when disabled" do
      System.put_env("BOLT_USER", "envuser")

      assert Config.new(@auth_opts).username == "envuser"
      assert Config.new(@auth_opts ++ [disable_env_fallback: true]).username == "optuser"
    end

    @tag :core
    test "BOLT_PWD overrides :auth by default, is ignored when disabled" do
      System.put_env("BOLT_PWD", "envpass")

      assert Config.new(@auth_opts).password == "envpass"
      assert Config.new(@auth_opts ++ [disable_env_fallback: true]).password == "optpass"
    end

    @tag :core
    test "BOLT_HOST is used as hostname fallback by default, is ignored when disabled" do
      System.put_env("BOLT_HOST", "envhost")

      # No :hostname and no :uri passed, so BOLT_HOST is the active fallback.
      assert Config.new(@auth_opts).hostname == "envhost"
      assert Config.new(@auth_opts ++ [disable_env_fallback: true]).hostname == "localhost"
    end

    @tag :core
    test "BOLT_TCP_PORT sets the default port by default, is ignored when disabled" do
      System.put_env("BOLT_TCP_PORT", "9999")

      assert Config.new(@auth_opts).port == 9999
      assert Config.new(@auth_opts ++ [disable_env_fallback: true]).port == 7687
    end

    @tag :core
    test "BOLT_VERSIONS sets versions by default, is ignored when disabled" do
      baseline = Config.new(@auth_opts).versions

      System.put_env("BOLT_VERSIONS", "1,2")

      default = Config.new(@auth_opts).versions
      assert 2.0 in default
      assert 1.0 in default
      refute default == baseline

      disabled = Config.new(@auth_opts ++ [disable_env_fallback: true]).versions
      assert disabled == baseline
      refute 2.0 in disabled
    end

    @tag :core
    test "disable_env_fallback: false explicitly keeps env fallback on" do
      System.put_env("BOLT_USER", "envuser")

      assert Config.new(@auth_opts ++ [disable_env_fallback: false]).username == "envuser"
    end

    @tag :core
    test "no env + no option: defaults preserved (backward compatible)" do
      config = Config.new(@auth_opts)

      assert config.username == "optuser"
      assert config.password == "optpass"
      assert config.hostname == "localhost"
      assert config.port == 7687
      assert config.versions == Versions.latest_versions() |> pad_and_sort()
    end
  end

  # Mirror Config.get_versions/1's tail processing so the baseline assertion is
  # independent of env reads.
  defp pad_and_sort(versions) do
    ((versions |> Enum.into([])) ++ [0, 0, 0]) |> Enum.take(4) |> Enum.sort(&>=/2)
  end
end
