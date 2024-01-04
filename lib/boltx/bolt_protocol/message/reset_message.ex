defmodule Boltx.BoltProtocol.Message.ResetMessage do
  @moduledoc false

  alias Boltx.Internals.PackStream.Message.Encoder
  alias Boltx.BoltProtocol.MessageDecoder

  def encode(bolt_version) when is_float(bolt_version) and bolt_version >= 3.0 do
    Encoder.do_encode(:reset, [], 3)
  end

  def encode(_) do
    {:error,
     Boltx.Error.wrap(__MODULE__, %{
       code: :unsupported_message_version,
       message: "RESET message version not supported"
     })}
  end

  @spec decode(float(), <<_::16, _::_*8>>) :: {:error, Boltx.Error.t()} | {:ok, any()}
  def decode(_bolt_version, binary_messages) do
    messages = Enum.map(binary_messages, &MessageDecoder.decode(&1))

    case hd(messages) do
      {:success, response} ->
        {:ok, response}

      {:failure, response} ->
        {:error,
         Boltx.Error.wrap(__MODULE__, %{code: response["code"], message: response["message"]})}
    end
  end
end
