# Boltx

Boltx is a derivative of Bolt_Sips currently in development. No official release has been made yet. The first version will be launched once queries with a Result structure return are achievable. Compatibility with Bolt_Sips is not a priority.

## Implemented messages

| Message       | Bolt Version                            |
| ------------- | --------------------------------------- |
| INIT          | V1, V2                                  |
| HELLO         | V3, V4.x, v5.1, v5.2, v5.3, v5.4        |
| LOGON         | V3, V4.x, v5.1, v5.2, v5.3, v5.4        |
| RUN           | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4|
| PULL          | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4|
| BEGIN         | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4|
| COMMIT        | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4|
| ROLLBACK      | V1, V2, V3, V4.x, v5.1, v5.2, v5.3, v5.4|
| LOGOFF        | --                                      |
| TELEMETRY     | --                                      |
| GOODBYE       | --                                      |
| RESET         | V3, V4.x, v5.1, v5.2, v5.3, v5.4        |
| DISCARD       | --                                      |
| ROUTE         | --                                      |
| ACK_FAILURE   | V1, V2                                  |


## Features

Currently, the focus is on refactoring Bolt Sips to enhance the way Bolt messages are implemented, making it easier to implement new versions of Bolt in the future.

| Feature               | Implemented |
| --------------------- | ------------ |
| Querys                | NO           |
| Routing               | NO           |
| Multi tenancy         | NO           |
| Stream capabilities   | NO           |
| Transactions          | NO           |
| Multi tenancy         | NO           |
