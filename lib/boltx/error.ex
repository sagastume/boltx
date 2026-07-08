defmodule Boltx.Error do
  @moduledoc false

  @error_map %{
    "Neo.ClientError.Security.Unauthorized" => :unauthorized,
    "Neo.ClientError.Request.Invalid" => :request_invalid,
    "Neo.ClientError.Statement.SemanticError" => :semantic_error,
    "Neo.ClientError.Statement.SyntaxError" => :syntax_error
  }

  @type t() :: %__MODULE__{
          module: module(),
          code: atom(),
          bolt: %{code: binary(), message: binary() | nil} | nil,
          packstream: %{bits: any() | nil} | nil
        }

  defexception [:module, :code, :bolt, :packstream]

  @spec wrap(module(), atom()) :: t()
  def wrap(module, code) when is_atom(code), do: %__MODULE__{module: module, code: code}

  @spec wrap(module(), binary()) :: t()
  def wrap(module, code) when is_binary(code), do: wrap(module, to_atom(code))

  @spec wrap(module(), map()) :: t()
  def wrap(module, bolt_error) when is_map(bolt_error),
    do: %__MODULE__{module: module, code: bolt_error.code |> to_atom(), bolt: bolt_error}

  def wrap(module, code, packstream),
    do: %__MODULE__{module: module, code: code, packstream: packstream}

  @doc """
  Return a copy of the error with the server-supplied free-text message removed.

  The Neo4j status `code` (in `bolt.code`) and the typed reason (`code`) are
  retained; only the free-text `bolt.message` is nil'd. Use this when the server
  message may contain caller/query bytes you must keep out of logs, crash
  reports, or error payloads that leave your boundary.

  A `%Boltx.Error{}` whose `bolt` is `nil` is returned unchanged.

  ### Examples

      iex> err = %Boltx.Error{bolt: %{code: "Neo.ClientError.Security.Unauthorized", message: "secret"}}
      iex> Boltx.Error.redact(err).bolt
      %{code: "Neo.ClientError.Security.Unauthorized", message: nil}

  """
  @spec redact(t()) :: t()
  def redact(%__MODULE__{bolt: %{} = bolt} = error),
    do: %__MODULE__{error | bolt: Map.put(bolt, :message, nil)}

  def redact(%__MODULE__{} = error), do: error

  @doc """
  Return the code for the given error.

  ### Examples

       iex> {:error, %Boltx.Error{} = error} = do_something()
       iex> Exception.message(error)
       "Unable to perform this action."


  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{code: code, module: module}) do
    module.format_error(code)
  end

  @doc """
  Gets the corresponding atom based on the error code.
  """
  @spec to_atom(t()) :: String.t()
  def to_atom(error_message) do
    Map.get(@error_map, error_message, :unknown)
  end
end

defimpl Inspect, for: Boltx.Error do
  import Inspect.Algebra

  # Render the error without the server-supplied free-text `bolt.message`, which
  # can contain caller/query bytes. The Neo4j status `bolt.code` and the typed
  # `code` are kept so the rendering stays useful for debugging. This keeps the
  # server text out of any log/crash report that inspects the struct (including
  # the `Exception.message/1` fallback path). The underlying field is left
  # untouched on the struct; use `Boltx.Error.redact/1` for a redacted copy.
  def inspect(%Boltx.Error{} = error, opts) do
    redacted_bolt =
      case error.bolt do
        %{message: message} = bolt when is_binary(message) ->
          %{bolt | message: "[redacted]"}

        other ->
          other
      end

    fields = [
      module: error.module,
      code: error.code,
      bolt: redacted_bolt,
      packstream: error.packstream
    ]

    concat(["#Boltx.Error<", to_doc(fields, opts), ">"])
  end
end
