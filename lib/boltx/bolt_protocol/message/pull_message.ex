defmodule Boltx.BoltProtocol.Message.PullMessage do

  import Boltx.BoltProtocol.ServerResponse

  alias Boltx.Internals.PackStream.Message.Encoder
  alias Boltx.Internals.PackStream.Message.Decoder

  def encode(bolt_version, extra_parameters) when is_float(bolt_version) and bolt_version >= 4.0 do
    message = [get_extra_parameters(extra_parameters)]
    Encoder.do_encode(:pull_all, message, 1)
  end

  def encode(bolt_version, _extra_parameters) when is_float(bolt_version) and bolt_version <= 3.0 do
    Encoder.do_encode(:pull_all, [], 1)
  end

  def encode(_, _) do
    {:error, %Boltx.Internals.Error{code: :unsupported_message_version, message: "PUll message version not supported"}}
  end

  @spec decode(float(), <<_::16, _::_*8>>) :: {:error, Boltx.Error.t()} | {:ok, any()}
  def decode(bolt_version, binary_messages) do
    messages = Enum.map(binary_messages, &Decoder.decode(&1, 1))
    records = Enum.reduce(messages, [], &group_record/2)

    success_data =
      if bolt_version <= 2.0 do
        Map.merge(%{"t_last" => messages[:success]["result_consumed_after"]}, Map.delete(messages[:success], "result_consumed_after"))
      else
        messages[:success]
      end

    {:ok, pull_result(records: records, success_data: success_data )}
  end

  defp get_extra_parameters(extra_parameters) do
    %{
      n: Map.get(extra_parameters, :n, -1),
      qid: Map.get(extra_parameters, :qid, -1),
    }
  end

  defp group_record({:record, data}, acc) do
    [data | acc]
  end

  defp group_record(_other, acc), do: acc
end
