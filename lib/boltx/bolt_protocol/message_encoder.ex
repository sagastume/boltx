defmodule Boltx.BoltProtocol.MessageEncoder do
  @moduledoc false

  alias Boltx.PackStream

  @max_chunk_size 65_535
  @end_marker <<0x00, 0x00>>
  @tiny_struct_marker 0xB
  @struct8_marker 0xDC
  @struct16_marker 0xDD

  def encode(signature, data) do
    Boltx.Utils.Logger.log_message(:client, :message_type, data)

    encoded =
      do_encode(signature, data)
      |> generate_chunks([])

    Boltx.Utils.Logger.log_message(:client, :message_type, encoded, :hex)
    encoded |> IO.iodata_to_binary()
  end

  defp do_encode(signature, list) when length(list) <= 15 do
    [
      <<@tiny_struct_marker::4, length(list)::4, signature>>,
      encode_list_data(list)
    ]
  end

  defp do_encode(signature, list) when length(list) <= 255 do
    [<<@struct8_marker::8, length(list)::8, signature>>, encode_list_data(list)]
  end

  defp do_encode(signature, list) when length(list) <= 65_535 do
    [
      <<@struct16_marker::8, length(list)::16, signature>>,
      encode_list_data(list)
    ]
  end

  defp encode_list_data(data) do
    Enum.map(
      data,
      &PackStream.pack!(&1)
    )
  end

  defp generate_chunks(<<>>, chunks) do
    [chunks, [@end_marker], []]
  end

  defp generate_chunks(data, chunks) do
    data_size = :erlang.iolist_size(data)

    case data_size > @max_chunk_size do
      true ->
        bindata = :erlang.iolist_to_binary(data)
        <<chunk::binary-@max_chunk_size, rest::binary>> = bindata
        new_chunk = format_chunk(chunk)
        generate_chunks(rest, [chunks, new_chunk])

      _ ->
        generate_chunks(<<>>, [chunks, format_chunk(data)])
    end
  end

  defp format_chunk(chunk) do
    [<<:erlang.iolist_size(chunk)::16>>, chunk]
  end
end
