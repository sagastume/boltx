defmodule Boltx.Response do
  import Boltx.BoltProtocol.ServerResponse

  @type t :: %__MODULE__{
          results: list,
          fields: list,
          records: list,
          plan: map,
          notifications: list,
          stats: list | map,
          profile: any,
          type: String.t(),
          bookmark: String.t()
        }

  @type key :: any
  @type value :: any
  @type acc :: any
  @type element :: any

  @doc """
  Una estructura que representa una consulta Boltx.

  * `statement` - La declaración de la consulta.
  * `extra` - Datos adicionales asociados con la consulta.
  """
  defstruct results: [],
            fields: nil,
            records: [],
            plan: nil,
            notifications: [],
            stats: [],
            profile: nil,
            type: nil,
            bookmark: nil

  def new(
        statement_result(
          result_run: result_run,
          result_pull: pull_result(records: records, success_data: success_data)
        )
      ) do
    fields = Map.get(result_run, "fields", [])

    %__MODULE__{
      results: create_results(fields, records),
      fields: fields,
      records: records,
      plan: Map.get(success_data, "plan", nil),
      notifications: Map.get(success_data, "notifications", []),
      stats: Map.get(success_data, "stats", []),
      profile: Map.get(success_data, "profile", nil),
      type: Map.get(success_data, "type", nil),
      bookmark: Map.get(success_data, "bookmark", nil)
    }
  end

  def first(%__MODULE__{results: []}), do: nil
  def first(%__MODULE__{results: [head | _tail]}), do: head

  @doc """
  Returns a lazy Stream of results.

  This allows for memory-efficient processing of large result sets
  by yielding records one at a time instead of loading everything into memory.

  ## Examples

      iex> response |> Response.stream() |> Enum.take(10)
      [%{"n" => 1}, %{"n" => 2}, ...]

      iex> response |> Response.stream() |> Stream.filter(&filter/1) |> Enum.to_list()
      [...]
  """
  def stream(%__MODULE__{results: results} = _response, _opts \\ []) do
    Stream.resource(
      # Start function: Initialize state
      fn -> results end,
      # Next function: Yield one result at a time
      fn
        [] -> {:halt, []}
        [head | tail] -> {[head], tail}
      end,
      # After function: Cleanup (nothing to clean up for in-memory results)
      fn _state -> :ok end
    )
  end

  @doc """
  Returns a lazy Stream that pulls records from the server in batches.

  This is for use with active connections where the result set hasn't been
  fully fetched yet. It will send PULL messages to fetch more records as needed.

  ## Options

    * `:fetch_size` - Number of records to fetch per PULL request (default: 1000)

  ## Examples

      iex> response |> Response.stream_with_client(client) |> Enum.take(100)
      # Only pulls enough records to satisfy the take
  """
  def stream_with_client(%__MODULE__{} = response, client, opts \\ []) do
    fetch_size = Keyword.get(opts, :fetch_size, 1000)

    Stream.resource(
      # Start function: Initialize state with buffer and metadata
      fn ->
        %{
          client: client,
          fetch_size: fetch_size,
          fields: response.fields,
          buffer: :queue.new(),
          # Assume more records initially
          has_more: true,
          # Query ID for PULL requests (if needed)
          qid: nil
        }
      end,
      # Next function: Fetch records lazily
      &fetch_next/1,
      # After function: Cleanup
      &cleanup/1
    )
  end

  # Fetch next record from buffer or pull more from server
  defp fetch_next(%{buffer: buffer, has_more: false} = state) do
    # No more records available from server
    case :queue.out(buffer) do
      {{:value, record}, new_buffer} ->
        {[record], %{state | buffer: new_buffer}}

      {:empty, _} ->
        {:halt, state}
    end
  end

  defp fetch_next(%{buffer: buffer, has_more: true} = state) do
    case :queue.out(buffer) do
      {{:value, record}, new_buffer} ->
        # Return record from buffer
        {[record], %{state | buffer: new_buffer}}

      {:empty, _} ->
        # Buffer empty, pull more from server
        case pull_batch(state) do
          {:ok, new_state} ->
            fetch_next(new_state)

          {:error, _reason} ->
            {:halt, state}
        end
    end
  end

  # Pull a batch of records from Neo4j
  defp pull_batch(%{client: client, fetch_size: fetch_size, fields: fields} = state) do
    import Boltx.BoltProtocol.ServerResponse

    extra_params = %{"n" => fetch_size}

    case Boltx.Client.send_pull(client, extra_params) do
      {:ok, pull_result(records: records, success_data: success_data)} ->
        # Convert records to results format
        results = create_results(fields, records)

        # Check if there are more records
        has_more = Map.get(success_data, "has_more", false)

        # Add results to buffer
        new_buffer =
          Enum.reduce(results, state.buffer, fn result, acc ->
            :queue.in(result, acc)
          end)

        {:ok, %{state | buffer: new_buffer, has_more: has_more}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cleanup(_state) do
    # No process cleanup needed - socket owned by caller
    :ok
  end

  defp create_results(fields, records) do
    records
    |> Enum.map(fn recs -> Enum.zip(fields, recs) end)
    |> Enum.map(fn data -> Enum.into(data, %{}) end)
  end
end
