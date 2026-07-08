defmodule Boltx.ErrorTest do
  use ExUnit.Case, async: true

  alias Boltx.Error

  @sensitive "sensitive server text with caller/query bytes"

  defp error_with_message do
    %Error{
      module: Boltx.Client,
      code: :unauthorized,
      bolt: %{code: "Neo.ClientError.Security.Unauthorized", message: @sensitive}
    }
  end

  describe "redact/1" do
    @tag :core
    test "removes the server-supplied free-text message but keeps the bolt code and typed code" do
      redacted = Error.redact(error_with_message())

      assert redacted.bolt.message == nil
      assert redacted.bolt.code == "Neo.ClientError.Security.Unauthorized"
      assert redacted.code == :unauthorized
      assert redacted.module == Boltx.Client
    end

    @tag :core
    test "is a no-op when bolt is nil" do
      err = %Error{module: Boltx.Client, code: :timeout, bolt: nil}
      assert Error.redact(err) == err
    end

    @tag :core
    test "does not raise when the bolt map lacks a :message key" do
      err = %Error{module: Boltx.Client, code: :unknown, bolt: %{code: "Some.Code"}}
      redacted = Error.redact(err)

      assert redacted.bolt.message == nil
      assert redacted.bolt.code == "Some.Code"
    end
  end

  describe "inspect/1" do
    @tag :core
    test "does not surface the server-supplied message" do
      output = inspect(error_with_message())

      refute output =~ @sensitive
    end

    @tag :core
    test "still renders the bolt status code so it is not vacuous" do
      output = inspect(error_with_message())

      assert output =~ "Neo.ClientError.Security.Unauthorized"
      assert output =~ "Boltx.Error"
    end

    @tag :core
    test "leaves the underlying message field intact on the struct for deliberate readers" do
      err = error_with_message()
      # Inspect only changes rendering, never the data.
      assert err.bolt.message == @sensitive
    end
  end
end
