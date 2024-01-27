defmodule Boltx.BoltProtocol.Message.CommitMessage do
  @moduledoc false

  alias Boltx.BoltProtocol.MessageEncoder

  @signature 0x12

  def encode(bolt_version) when is_float(bolt_version) and bolt_version >= 3.0 do
    message = []
    MessageEncoder.encode(@signature, message)
  end

  def encode(_) do
    {:error,
     Boltx.Error.wrap(__MODULE__, %{
       code: :unsupported_message_version,
       message: "COMMIT message version not supported"
     })}
  end
end
