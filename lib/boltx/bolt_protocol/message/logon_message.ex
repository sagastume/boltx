defmodule Boltx.BoltProtocol.Message.LogonMessage do
  @moduledoc false

  import Boltx.BoltProtocol.Message.Shared.AuthHelper

  alias Boltx.BoltProtocol.MessageEncoder

  @signature 0x6A

  def encode(bolt_version, fields) when is_float(bolt_version) and bolt_version >= 3.0 do
    message = [get_auth_params(fields)]
    MessageEncoder.encode(@signature, message)
  end

  def encode(_, _) do
    {:error,
     Boltx.Error.wrap(__MODULE__, %{
       code: :unsupported_message_version,
       message: "LOGON message version not supported"
     })}
  end
end
