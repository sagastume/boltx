defmodule Boltx.BoltProtocol.Message.Shared.AuthHelper do
  @moduledoc false

  def get_auth_params(fields) do
    %{
      scheme: "basic",
      principal: fields[:auth][:username],
      credentials: fields[:auth][:password]
    }
  end

  def get_user_agent(fields) do
    default_user_agent = "boltx/" <> to_string(Application.spec(:boltx, :vsn))
    Keyword.get(fields, :user_agent, default_user_agent)
  end

  def get_user_agent(_bolt_version, fields) do
    default_user_agent = "boltx/" <> to_string(Application.spec(:boltx, :vsn))
    user_agent = Keyword.get(fields, :user_agent, default_user_agent)
    %{user_agent: user_agent}
  end

  def get_bolt_agent(_fields) do
    system_info = System.build_info()
    product = "boltx/" <> to_string(Application.spec(:boltx, :vsn))

    %{
      bolt_agent: %{
        product: product,
        language: "Elixir/" <> system_info.version,
        language_details: system_info.build
      }
    }
  end
end
