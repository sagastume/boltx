defmodule Boltx.BoltProtocol.Message.LogonMessage do
  import Boltx.BoltProtocol.Message.Shared.AuthHelper

  alias Boltx.Internals.PackStream.Message.Encoder
  alias Boltx.Internals.PackStream.Message.Decoder

  def encode(bolt_version, fields) when is_float(bolt_version) and bolt_version >= 3.0 do
    message = [get_auth_params(fields)]
    Encoder.do_encode(:logon, message, 3)
  end

  def encode(_, _) do
    {:error,
     Boltx.Error.wrap(__MODULE__, %{
       code: :unsupported_message_version,
       message: "LOGON message version not supported"
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
end
