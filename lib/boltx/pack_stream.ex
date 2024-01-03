defmodule Boltx.PackStream do
  alias Boltx.PackStream.Packer
  alias Boltx.PackStream.Unpacker

  def pack(term, options \\ []) do
    iodata? = Keyword.get(options, :iodata, false)

    try do
      Packer.pack(term)
    catch
      :throw, error ->
        {:error, error}

      :error, %Protocol.UndefinedError{protocol: Boltx.PackStream.Packer} = exception ->
        {:error, exception}
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
  def unpack(iodata) do
    try do
      iodata
      |> Unpacker.unpack()
    catch
      :throw, error ->
        {:error, error}
    else
      value ->
        {:ok, value}
    end
  end

  def unpack!(iodata) do
    case unpack(iodata) do
      {:ok, value} ->
        value

      {:error, exception} ->
        raise exception
    end
  end
end
