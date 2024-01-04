defmodule Boltx.BoltProtocol.Message.RunMessage do
  @moduledoc false

  alias Boltx.Internals.PackStream.Message.Encoder
  alias Boltx.BoltProtocol.MessageDecoder

  def encode(bolt_version, query, parameters, extra_parameters)
      when is_float(bolt_version) and bolt_version >= 3.0 do
    message = [query, parameters, get_extra_parameters(extra_parameters)]
    Encoder.do_encode(:run, message, 3)
  end

  def encode(bolt_version, query, parameters, _extra_parameters)
      when is_float(bolt_version) and bolt_version <= 2.0 do
    message = [query, parameters]
    Encoder.do_encode(:run, message, 3)
  end

  def encode(_, _, _, _) do
    {:error,
     Boltx.Error.wrap(__MODULE__, %{
       code: :unsupported_message_version,
       message: "RUN message version not supported"
     })}
  end

  @spec decode(float(), <<_::16, _::_*8>>) :: {:error, Boltx.Error.t()} | {:ok, any()}
  def decode(bolt_version, binary_messages) do
    messages = Enum.map(binary_messages, &MessageDecoder.decode(&1))

    case hd(messages) do
      {:success, response} ->
        case bolt_version <= 2.0 do
          true ->
            {:ok,
             Map.merge(
               %{"t_first" => response["result_available_after"]},
               Map.delete(response, "result_available_after")
             )}

          false ->
            {:ok, response}
        end

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
