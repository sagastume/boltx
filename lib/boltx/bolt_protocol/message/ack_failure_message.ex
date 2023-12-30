defmodule Boltx.BoltProtocol.Message.AckFailureMessage do
  @moduledoc false

  alias Boltx.Internals.PackStream.Message.Encoder
  alias Boltx.Internals.PackStream.Message.Decoder

  def encode(bolt_version) when is_float(bolt_version) and bolt_version <= 2.0 do
    Encoder.do_encode(:ack_failure, [], 1)
  end

  def encode(_) do
    {:error,
     Boltx.Error.wrap(__MODULE__, %{
       code: :unsupported_message_version,
       message: "ACK FAILURE message version not supported"
     })}
  end

  @spec decode(float(), <<_::16, _::_*8>>) :: {:error, Boltx.Error.t()} | {:ok, any()}
  def decode(_bolt_version, binary_messages) do
    messages = Enum.map(binary_messages, &Decoder.decode(&1, 1))

    case hd(messages) do
      {:success, response} ->
        {:ok, response}

      {:failure, response} ->
        {:error,
         Boltx.Error.wrap(__MODULE__, %{code: response["code"], message: response["message"]})}
    end
  end
end
