# Changelog

## v0.0.6 (2024-02-18)
  * Fix Error querying all nodes after buffering change in 4.0
  * Implement ping to check session health
  * Adds Generic Decoder
  * Code improvements

## v0.0.5 (2024-01-21)
  * Support for DateTime, Legacy DateTime, DateTimeZoneId and Legacy DateTimeZoneId structures added in bolt version 5.
  * Update of db_connection from 2.4.3 to 2.6.0

## v0.0.4 (2024-01-09)
  * Documentation update
  * Add child_spec to return a specification for a DBConnection pool

## v0.0.3 (2024-01-06)
  * Validates the URI scheme.
  * Utilizes the bolt+s scheme by default, with [verify: :verify_none] as the TLSOptions.
  * Establishes secure SSL/TLS connections.
  * Refactoring of packstream, optimizing the encoding and decoding processes for efficient message handling.