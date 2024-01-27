defmodule Boltx.BoltProtocol.Message.LogoffMessage do
  @moduledoc false

  alias Boltx.BoltProtocol.MessageEncoder

  @signature 0x6B

  def encode(bolt_version) when is_float(bolt_version) and bolt_version >= 5.1 do
    MessageEncoder.encode(@signature, [])
  end

  def encode(_) do
    {:error,
     Boltx.Error.wrap(__MODULE__, %{
       code: :unsupported_message_version,
       message: "LOGOFF message version not supported"
     })}
  end
end
