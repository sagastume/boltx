defmodule Boltx.BoltProtocol.Message.HelloMessage do
  import Boltx.BoltProtocol.Message.Shared.AuthHelper

  alias Boltx.Internals.PackStream.Message.Encoder
  alias Boltx.Internals.PackStream.Message.Decoder

  def encode(bolt_version, fields) when is_float(bolt_version) and bolt_version >= 5.1 do
    message = [
      get_user_agent(bolt_version, fields)
      |> Map.merge(get_bolt_agent(fields))
      |> Map.merge(get_extra_parameters(fields))
    ]

    Encoder.do_encode(:hello, message, 3)
  end

  def encode(bolt_version, fields) when is_float(bolt_version) and bolt_version >= 3.0 do
    message = [Map.merge(get_auth_params(fields), get_user_agent(bolt_version, fields))]
    Encoder.do_encode(:hello, message, 3)
  end

  def encode(_, _) do
    {:error,
     Boltx.Error.wrap(__MODULE__, %{
       code: :unsupported_message_version,
       message: "HELLO message version not supported"
     })}
  end

  def decode(_bolt_version, binary_messages) do
    messages = Enum.map(binary_messages, &Decoder.decode(&1, 3))
    response = hd(messages)

    case response do
      {:success, response} ->
        {:ok, response}

      {:failure, response} ->
        {:error,
         Boltx.Error.wrap(__MODULE__, %{code: response["code"], message: response["message"]})}
    end
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
