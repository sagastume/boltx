defmodule ResponseTest do
  use ExUnit.Case

  import Boltx.BoltProtocol.ServerResponse
  alias Boltx.Response

  @mock_plan %{
    "plan" => %{
      "args" => %{
        "EstimatedRows" => 1.0,
        "planner" => "COST",
        "planner-impl" => "IDP",
        "planner-version" => "3.5",
        "runtime" => "INTERPRETED",
        "runtime-impl" => "INTERPRETED",
        "runtime-version" => "3.5",
        "version" => "CYPHER 3.5"
      },
      "children" => [
        %{
          "args" => %{"EstimatedRows" => 1.0},
          "children" => [],
          "identifiers" => ["n"],
          "operatorType" => "Create"
        }
      ],
      "identifiers" => ["n"],
      "operatorType" => "ProduceResults"
    }
  }

  @mock_notification %{
    "notifications" => [
      %{
        "code" => "Neo.ClientNotification.Statement.CartesianProductWarning",
        "description" => "bad juju",
        "position" => %{"column" => 9, "line" => 1, "offset" => 8},
        "severity" => "WARNING",
        "title" => "This query builds a cartesian product between disconnected patterns."
      }
    ]
  }

  @mock_bookmark %{"bookmark" => "neo4j:bookmark:v1:tx13440"}

  @mock_profile %{
    "profile" => %{
      "args" => %{
        "DbHits" => 0,
        "EstimatedRows" => 1.0,
        "PageCacheHitRatio" => 0.0,
        "PageCacheHits" => 0,
        "PageCacheMisses" => 0,
        "Rows" => 0,
        "planner" => "COST",
        "planner-impl" => "IDP",
        "planner-version" => "3.5",
        "runtime" => "SLOTTED",
        "runtime-impl" => "SLOTTED",
        "runtime-version" => "3.5",
        "version" => "CYPHER 3.5"
      }
    }
  }

  @mock_stats %{
    "stats" => %{
      "labels-added" => 1,
      "nodes-created" => 1,
      "properties-set" => 1
    }
  }

  describe "Response new/1" do
    @tag :core
    test "create a new response from the run_statement with a single field" do
      result =
        statement_result(
          result_run: %{"fields" => ["r"], "t_first" => 24},
          result_pull: {:pull_result, [[300]], %{"t_last" => 2, "type" => "r"}},
          query: ""
        )

      assert %Response{results: results, fields: fields, records: records} = Response.new(result)
      assert results == [%{"r" => 300}]
      assert fields == ["r"]
      assert records == [[300]]
    end

    @tag :core
    test "create a new response from the run_statement with a many field" do
      result =
        statement_result(
          result_run: %{"fields" => ["price", "name", "cost"], "t_first" => 24},
          result_pull: {:pull_result, [[50, "Galletas", 20]], %{"t_last" => 2, "type" => "r"}},
          query: ""
        )

      assert %Response{results: results, fields: fields, records: records} = Response.new(result)
      assert results == [%{"price" => 50, "name" => "Galletas", "cost" => 20}]
      assert fields == ["price", "name", "cost"]
      assert records == [[50, "Galletas", 20]]
    end

    @tag :core
    test "create a new response from the run_statement with a many records" do
      result =
        statement_result(
          result_run: %{"fields" => ["price", "name", "cost"], "t_first" => 24},
          result_pull:
            {:pull_result, [[50, "Galletas", 20], [10, "Pastillas", 5]],
             %{"t_last" => 2, "type" => "r"}},
          query: ""
        )

      assert %Response{results: results, fields: fields, records: records} = Response.new(result)

      assert results == [
               %{"price" => 50, "name" => "Galletas", "cost" => 20},
               %{"price" => 10, "name" => "Pastillas", "cost" => 5}
             ]

      assert fields == ["price", "name", "cost"]
      assert records == [[50, "Galletas", 20], [10, "Pastillas", 5]]
    end

    @tag :core
    test "creating a response from the run_statement with empty result" do
      result =
        statement_result(
          result_run: %{"fields" => ["price", "name", "cost"], "t_first" => 24},
          result_pull: {:pull_result, [], %{"t_last" => 2, "type" => "r"}},
          query: ""
        )

      assert %Response{results: results, fields: fields, records: records} = Response.new(result)
      assert results == []
      assert fields == ["price", "name", "cost"]
      assert records == []
    end

    @tag :core
    test "creating a response from the run_statement with plan" do
      result =
        statement_result(
          result_run: %{"fields" => ["price", "name", "cost"], "t_first" => 24},
          result_pull: {:pull_result, [], Map.merge(%{"t_last" => 2, "type" => "r"}, @mock_plan)},
          query: ""
        )

      assert %Response{plan: plan} = Response.new(result)
      assert plan == Map.get(@mock_plan, "plan")
    end

    @tag :core
    test "creating a response from the run_statement with notifications" do
      result =
        statement_result(
          result_run: %{"fields" => ["price", "name", "cost"], "t_first" => 24},
          result_pull:
            {:pull_result, [], Map.merge(%{"t_last" => 2, "type" => "r"}, @mock_notification)},
          query: ""
        )

      assert %Response{notifications: notifications} = Response.new(result)
      assert notifications == Map.get(@mock_notification, "notifications")
    end

    @tag :core
    test "creating a response from the run_statement with bookmark" do
      result =
        statement_result(
          result_run: %{"fields" => ["price", "name", "cost"], "t_first" => 24},
          result_pull:
            {:pull_result, [], Map.merge(%{"t_last" => 2, "type" => "r"}, @mock_bookmark)},
          query: ""
        )

      assert %Response{bookmark: bookmark} = Response.new(result)
      assert bookmark == Map.get(@mock_bookmark, "bookmark")
    end

    @tag :core
    test "creating a response from the run_statement with profile" do
      result =
        statement_result(
          result_run: %{"fields" => ["price", "name", "cost"], "t_first" => 24},
          result_pull:
            {:pull_result, [], Map.merge(%{"t_last" => 2, "type" => "r"}, @mock_profile)},
          query: ""
        )

      assert %Response{profile: profile} = Response.new(result)
      assert profile == Map.get(@mock_profile, "profile")
    end

    @tag :core
    test "creating a response from the run_statement with stats" do
      result =
        statement_result(
          result_run: %{"fields" => ["price", "name", "cost"], "t_first" => 24},
          result_pull:
            {:pull_result, [], Map.merge(%{"t_last" => 2, "type" => "r"}, @mock_stats)},
          query: ""
        )

      assert %Response{stats: stats} = Response.new(result)
      assert stats == Map.get(@mock_stats, "stats")
    end

    @tag :core
    test "creating a response from the run_statement with type" do
      result =
        statement_result(
          result_run: %{"fields" => ["price", "name", "cost"], "t_first" => 24},
          result_pull: {:pull_result, [], %{"t_last" => 2, "type" => "r"}},
          query: ""
        )

      assert %Response{type: type} = Response.new(result)
      assert type == "r"
    end
  end
end
