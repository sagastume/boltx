defmodule Boltx.BoltProtocol.Message.RollbackMessage do

  alias Boltx.Internals.PackStream.Message.Encoder
  alias Boltx.Internals.PackStream.Message.Decoder

  def encode(bolt_version) when is_float(bolt_version) and bolt_version >= 3.0 do
    message = []
    Encoder.do_encode(:rollback, message, 3)
  end

  def encode(_, _) do
    {:error, %Boltx.Internals.Error{code: :unsupported_message_version, message: "ROLLBACK message version not supported"}}
  end

  @spec decode(float(), <<_::16, _::_*8>>) :: {:error, Boltx.Error.t()} | {:ok, any()}
  def decode(_bolt_version, binary_messages) do
    messages = Enum.map(binary_messages, &Decoder.decode(&1, 1))

    case hd(messages) do
      {:success, response} ->
        {:ok, response}
      {:failure, response} ->
        {:error, Boltx.Error.wrap(__MODULE__, %{code: response["code"], message: response["message"]})}
    end
  end
end
