defmodule Boltx.BoltProtocol.Message.HelloMessage do
  @moduledoc false

  import Boltx.BoltProtocol.Message.Shared.AuthHelper

  alias Boltx.BoltProtocol.MessageEncoder

  @signature 0x01

  def encode(bolt_version, fields) when is_float(bolt_version) and bolt_version >= 5.1 do
    message = [
      bolt_version
      |> get_user_agent(fields)
      |> Map.merge(get_bolt_agent(fields))
      |> Map.merge(get_extra_parameters(fields))
    ]

    MessageEncoder.encode(@signature, message)
  end

  def encode(bolt_version, fields) when is_float(bolt_version) and bolt_version >= 3.0 do
    message = [Map.merge(get_auth_params(fields), get_user_agent(bolt_version, fields))]
    MessageEncoder.encode(@signature, message)
  end

  def encode(_, _) do
    {:error,
     Boltx.Error.wrap(__MODULE__, %{
       code: :unsupported_message_version,
       message: "HELLO message version not supported"
     })}
  end

  defp get_extra_parameters(fields) do
    keys_to_extract = [:notifications_minimum_severity, :notifications_disabled_categories]

    Enum.reduce(keys_to_extract, %{}, fn key, acc ->
      case Keyword.get(fields, key) do
        nil -> acc
        value -> Map.put_new(acc, key, value)
      end
    end)
  end
end
