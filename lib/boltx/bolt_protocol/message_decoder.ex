defmodule Boltx.BoltProtocol.MessageDecoder do
  @moduledoc false

  alias Boltx.PackStream

  @type in_signature :: :failure | :ignored | :record | :success
  @type encoded :: <<_::16, _::_*8>>
  @type decoded :: {in_signature(), any()}

  @tiny_struct_marker 0xB
  @success_signature 0x70
  @failure_signature 0x7F
  @record_signature 0x71
  @ignored_signature 0x7E

  @spec decode(encoded()) :: decoded()
  def decode(<<@tiny_struct_marker::4, nb_entries::4, @success_signature, data::binary>>) do
    build_response(:success, data, nb_entries)
  end

  @spec decode(encoded()) :: decoded()
  def decode(<<@tiny_struct_marker::4, nb_entries::4, @failure_signature, data::binary>>) do
    build_response(:failure, data, nb_entries)
  end

  @spec decode(encoded()) :: decoded()
  def decode(<<@tiny_struct_marker::4, nb_entries::4, @record_signature, data::binary>>) do
    build_response(:record, data, nb_entries)
  end

  @spec decode(encoded()) :: decoded()
  def decode(<<@tiny_struct_marker::4, nb_entries::4, @ignored_signature, data::binary>>) do
    build_response(:ignored, data, nb_entries)
  end

  defp build_response(message_type, data, nb_entries) do
    Boltx.Utils.Logger.log_message(:server, message_type, data, :hex)

    response =
      case PackStream.unpack(data) do
        {:ok, response} when nb_entries == 1 ->
          List.first(response)

        {:ok, response} ->
          response
      end

      Boltx.Utils.Logger.log_message(:server, message_type, response)
    {message_type, response}
  end
end
