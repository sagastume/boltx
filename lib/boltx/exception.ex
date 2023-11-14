defmodule Boltx.Exception do
  @moduledoc """
  This module defines a `Boltx.Exception` structure containing two fields:

  * `code` - the error code
  * `message` - the error details
  """
  @type t :: %Boltx.Exception{}

  defexception [:code, :message]
end
