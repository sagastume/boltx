defmodule Boltx.BoltProtocol.Message.ResetMessage do
  @moduledoc false

  alias Boltx.BoltProtocol.MessageEncoder

  @signature 0x0F

  def encode(bolt_version) when is_float(bolt_version) and bolt_version >= 3.0 do
    MessageEncoder.encode(@signature, [])
  end

  def encode(_) do
    {:error,
     Boltx.Error.wrap(__MODULE__, %{
       code: :unsupported_message_version,
       message: "RESET message version not supported"
     })}
  end
end
