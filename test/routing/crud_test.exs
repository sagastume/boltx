defmodule Boltx.Routing.CrudTest do
  use Boltx.RoutingConnCase
  @moduletag :routing

  alias Boltx

  describe "Basic Read/Write; " do
    test "read" do
      cypher = "return 10 as n"

      assert [%{"n" => 10}] ==
               Boltx.query!(Boltx.conn(:read), cypher)
    end

    test "write" do
      conn = Boltx.conn(:write)
      cypher = "CREATE (elf:Elf { name: $name, from: $from, klout: 99 })"

      assert %{
               stats: %{
                 "labels-added" => 1,
                 "nodes-created" => 1,
                 "properties-set" => 3
               },
               type: "w"
             } == Boltx.query!(conn, cypher, %{name: "Arameil", from: "Sweden"})
    end

    # https://neo4j.com/docs/cypher-manual/current/clauses/set/#set-adding-properties-from-maps
    test "update" do
      create_cypher = "CREATE (p:Person { first: $person.first, last: $person.last })"

      update_cypher = """
      MATCH (p:Person{ first: 'Green', last: 'Alien' })
        SET p.first = { person }.first, p.last = $person.last
        RETURN p.first as first_name, p.last as last_name
      """

      conn = Boltx.conn(:write)

      assert %{
               stats: %{
                 "labels-added" => 1,
                 "nodes-created" => 1,
                 "properties-set" => 2
               },
               type: "w"
             } ==
               Boltx.query!(conn, create_cypher, %{person: %{first: "Green", last: "Alien"}})

      assert [%{"last_name" => "Alien"}] ==
               Boltx.query!(
                 conn,
                 "MATCH (p:Person { first: 'Green', last: 'Alien' }) RETURN p.last AS last_name"
               )

      assert [%{"first_name" => "Florin", "last_name" => "Pătraşcu"}] ==
               Boltx.query!(conn, update_cypher, %{person: %{first: "Florin", last: "Pătraşcu"}})
    end

    test "upsert" do
      # MERGE (p:Person{ first: { map }.name, last: { map }.last }
      # ON CREATE SET n = { map }
      # ON MATCH  SET n += { map }
    end
  end
end
