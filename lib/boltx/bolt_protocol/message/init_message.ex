defmodule Boltx.BoltProtocol.Message.InitMessage do
  @moduledoc false

  import Boltx.BoltProtocol.Message.Shared.AuthHelper

  alias Boltx.BoltProtocol.MessageEncoder
  alias Boltx.BoltProtocol.MessageDecoder

  @signature 0x01

  def encode(bolt_version, fields) when is_float(bolt_version) and bolt_version >= 1.0 do
    message = [get_user_agent(fields), get_auth_params(fields)]
    MessageEncoder.encode(@signature, message)
  end

  def encode(_, _) do
    {:error,
     Boltx.Error.wrap(__MODULE__, %{
       code: :unsupported_message_version,
       message: "INIT message version not supported"
     })}
  end

  def decode(_bolt_version, binary_messages) do
    messages = Enum.map(binary_messages, &MessageDecoder.decode(&1))
    response = hd(messages)

    case response do
      {:success, response} ->
        {:ok, response}

      {:failure, response} ->
        {:error,
         Boltx.Error.wrap(__MODULE__, %{code: response["code"], message: response["message"]})}
    end
  end
end
