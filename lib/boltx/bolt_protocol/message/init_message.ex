defmodule Boltx.BoltProtocol.Message.InitMessage do
  import Boltx.BoltProtocol.Message.Shared.AuthHelper

  alias Boltx.Internals.PackStream.Message.Encoder
  alias Boltx.Internals.PackStream.Message.Decoder

  def encode(bolt_version, fields) when is_float(bolt_version) and bolt_version >= 1.0 do
    message = [get_user_agent(fields), get_auth_params(fields)]
    Encoder.do_encode(:init, message, 1)
  end

  def encode(_, _) do
    {:error, %Boltx.Internals.Error{code: :unsupported_message_version, message: "Init message version not supported"}}
  end

  def decode(response_message) do
    case Decoder.decode(response_message, 1) do
      {:success, response} ->
        {:ok, response}
      {:failure, response} ->
        {:error, Boltx.Error.wrap(__MODULE__, %{code: response["code"], message: response["message"]})}
    end
  end
end
