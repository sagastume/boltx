defmodule Boltx.PackStream do
  alias Boltx.PackStream.Packer
  alias Boltx.PackStream.Unpacker

  def pack(term, options \\ []) do
    iodata? = Keyword.get(options, :iodata, false)

    try do
      Packer.pack(term)
    catch
      :throw, reason ->
        {:error, %{reason: reason}}
    else
      iodata when iodata? ->
        {:ok, iodata}

      iodata ->
        {:ok, IO.iodata_to_binary(iodata)}
    end
  end

  @spec pack!(term, Keyword.t()) :: iodata | no_return
  def pack!(term, options \\ []) do
    case pack(term, options) do
      {:ok, result} ->
        result

      {:error, exception} ->
        raise exception
    end
  end

  @spec unpack(binary()) :: list()
  def unpack(iodata) when is_bitstring(iodata) do
    iodata
    |> IO.iodata_to_binary()
    |> Unpacker.unpack()
  end

  def unpack({signature, struct_binary, struct_size}) do
    Unpacker.unpack({signature, IO.iodata_to_binary(struct_binary), struct_size})
  end

  def unpack!(iodata) do
    unpack(iodata)
  end
end
