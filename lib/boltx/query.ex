defmodule Boltx.Query do
  @moduledoc """
  This module defines a structure to represent Boltx single query.

  A Boltx query consists of a statement and additional data (extra).

  """

  @typedoc """
  Extra contains additional options. _Introduced in bolt 3_

  * `:bookmarks` -  is a list of strings containing some kind of bookmark identification, e.g.,
   ["neo4j-bookmark-transaction:1", "neo4j-bookmark-transaction:2"]. (default: `[]`).

  * `:mode` - specifies what kind of server the RUN message is targeting. For write access
   use "w" and for read access use "r". (default: `w`).

  * `:db` - specifies the database name for multi-database to select where the transaction
   takes place. null and "" denote the server-side configured default database.
   (default: `null`) _Introduced in bolt 4.0_

  * `:tx_metadata` - is a map that can contain some metadata information, mainly used for logging. (default: `null`)
  """
  @type extra() ::
          {:bookmarks, list(String.t()) | nil}
          | {:mode, String.t() | nil}
          | {:db, String.t() | nil}
          | {:tx_metadata, String.t() | nil}
  @type t :: %__MODULE__{
          statement: String.t(),
          extra: extra()
        }
  defstruct statement: "",
            extra: %{}
end

defmodule Boltx.Queries do
  @moduledoc """
  This module defines a structure to represent Boltx queries.

  It consists of a statement and additional data (extra). The extra configuration applies to all queries.
  """

  @type t :: %__MODULE__{
          statement: String.t(),
          extra: Boltx.Query.extra()
        }
  defstruct statement: "",
            extra: %{}
end

defimpl DBConnection.Query, for: [Boltx.Query, Boltx.Queries] do
  def describe(query, _), do: query

  def parse(query, _), do: query

  def encode(_query, data, _), do: data

  def decode(_, result, _), do: result
end
