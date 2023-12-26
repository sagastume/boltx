alias Boltx.Utils.Converters

Logger.configure(level: :debug)

exclude = [
  :skip,
  :bench,
  :apoc,
  :legacy
]

include = [:core]

available_versions = Boltx.BoltProtocol.Versions.available_versions()

env_versions =
  System.get_env("BOLT_VERSIONS", "")
  |> String.split(",")
  |> Enum.reject(&(&1 == ""))
  |> Enum.map(&Converters.to_float/1)

{include, exclude} =
  Enum.reduce(available_versions, {include, exclude}, fn version, {inc, exc} ->
    [major | [minor]] =
      version |> Float.to_string() |> String.split(".") |> Enum.map(&String.to_integer/1)

    bolt_version_atom =
      String.to_atom("bolt_version_#{Integer.to_string(major)}_#{Integer.to_string(minor)}")

    bolt_version_x = String.to_atom("bolt_#{Integer.to_string(trunc(version))}_x")

    if version in env_versions do
      case version === List.last(available_versions) do
        true -> {[:last_version, bolt_version_x, bolt_version_atom | inc], exc}
        false -> {[bolt_version_x, bolt_version_atom | inc], exc}
      end
    else
      case version !== List.last(available_versions) do
        true -> {inc, [:last_version, bolt_version_x, bolt_version_atom | exc]}
        false -> {inc, [bolt_version_x, bolt_version_atom | exc]}
      end
    end
  end)

ExUnit.start(capture_log: true, assert_receive_timeout: 500, exclude: exclude, include: include)
Application.ensure_started(:porcelain)

defmodule Boltx.TestHelper do
  def opts() do
    [
      address: "127.0.0.1",
      auth: [username: "neo4j", password: "boltxPassword"],
      bolt_agent: [product: "boltxTest/1"],
      pool_size: 15,
      max_overflow: 3,
      prefix: :default
    ]
  end

  def opts_without_auth() do
    [
      address: "127.0.0.1",
      bolt_agent: [product: "boltxTest/1"],
      pool_size: 15,
      max_overflow: 3,
      prefix: :default
    ]
  end

  @doc """
   Read an entire file into a string.
   Return a tuple of success and data.
  """
  def read_whole_file(path) do
    case File.read(path) do
      {:ok, file} -> file
      {:error, reason} -> {:error, "Could not open #{path} #{file_error_description(reason)}"}
    end
  end

  @doc """
    Open a file stream, and join the lines into a string.
  """
  def stream_file_join(filename) do
    stream = File.stream!(filename)
    Enum.join(stream)
  end

  defp file_error_description(:enoent), do: "because the file does not exist."
  defp file_error_description(reason), do: "due to #{reason}."
end

# Boltx.start_link(Application.get_env(:boltx, Bolt))

# I am using the test db for debugging and the line below will clear *everything*
# Boltx.query(Boltx.conn, "MATCH (n) OPTIONAL MATCH (n)-[r]-() DELETE n,r")
#
# todo: The tests should cleanup the data they create.

Process.flag(:trap_exit, true)
