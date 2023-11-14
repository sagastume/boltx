defmodule Boltx.Application do
  @moduledoc false

  use Application

  alias Boltx

  def start(_, start_args) do
    Boltx.start_link(start_args)
  end

  def stop(_state) do
    :ok
  end
end
