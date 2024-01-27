defmodule Boltx.BoltProtocol.Message.AckFailureMessage do
  @moduledoc false

  alias Boltx.BoltProtocol.MessageEncoder

  @signature 0x0E

  def encode(bolt_version) when is_float(bolt_version) and bolt_version <= 2.0 do
    MessageEncoder.encode(@signature, [])
  end

  def encode(_) do
    {:error,
     Boltx.Error.wrap(__MODULE__, %{
       code: :unsupported_message_version,
       message: "ACK FAILURE message version not supported"
     })}
  end
end
