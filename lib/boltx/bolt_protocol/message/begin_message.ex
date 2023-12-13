defmodule Boltx.BoltProtocol.Message.BeginMessage do
  alias Boltx.Internals.PackStream.Message.Encoder
  alias Boltx.Internals.PackStream.Message.Decoder

  def encode(bolt_version, extra_parameters)
      when is_float(bolt_version) and bolt_version >= 3.0 do
    message = [get_extra_parameters(extra_parameters)]
    Encoder.do_encode(:begin, message, 3)
  end

  def encode(_, _) do
    {:error,
     %Boltx.Internals.Error{
       code: :unsupported_message_version,
       message: "BEGIN message version not supported"
     }}
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

  defp get_extra_parameters(extra_parameters) do
    %{
      bookmarks: Map.get(extra_parameters, :bookmarks, []),
      mode: Map.get(extra_parameters, :mode, "w"),
      db: Map.get(extra_parameters, :db, nil),
      tx_metadata: Map.get(extra_parameters, :tx_metadata, nil)
    }
  end
end
