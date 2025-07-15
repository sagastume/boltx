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
  Return the code for the given error.

  ### Examples

       iex> {:error, %Boltx.Error{} = error} = do_something()
       iex> Exception.message(error)
       "Unable to perform this action."


  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{code: code, module: module} = error) do
    if code == :syntax_error do
      """
      Syntax error
      #{error.bolt.message}
      """
    else
      inspect(error, pretty: true)
    end
    # TODO: move to module.format_error(code) later
  end

  @doc """
  Gets the corresponding atom based on the error code.
  """
  @spec to_atom(t()) :: String.t()
  def to_atom(error_message) do
    Map.get(@error_map, error_message, :unknown)
  end
end
