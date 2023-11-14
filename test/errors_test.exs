defmodule ErrorsTest do
  @moduledoc """
  every new error, and related tests
  """
  use ExUnit.Case, async: true

  @simple_map %{foo: "bar", boltx: true}
  @nested_map %{
    foo: "bar",
    boltx: true,
    a_map: %{unu: 1, doi: 2, baz: "foo"},
    a_list: [1, 2, 3.14]
  }

  test "create a node using SET properties and a simple map" do
    %Boltx.Response{stats: stats, type: type} =
      Boltx.query!(Boltx.conn(), "CREATE (report:Report) SET report = $props", %{
        props: @simple_map
      })

    assert %{"labels-added" => 1, "nodes-created" => 1, "properties-set" => 2} == stats
    assert "w" == type
  end

  test "exception when creating a node using SET properties with a nested map" do
    err = "Property values can only be of primitive types or arrays thereof"

    assert_raise Boltx.Exception, err, fn ->
      Boltx.query!(
        Boltx.conn(),
        "CREATE (report:Report) SET report = $props",
        %{props: @nested_map}
      )
    end
  end

  test "exception when creating a node using SET properties with a list" do
    assert_raise Boltx.Exception, fn ->
      Boltx.query!(Boltx.conn(), "CREATE (report:Report) SET report = $props", %{
        props: ["foo", "bar"]
      })
    end
  end
end
