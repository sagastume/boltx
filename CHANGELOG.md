# Changelog

## v0.0.4 (2024-01-09)
  * Documentation update
  * Add child_spec to return a specification for a DBConnection pool

## v0.0.3 (2024-01-06)
  * Validates the URI scheme.
  * Utilizes the bolt+s scheme by default, with [verify: :verify_none] as the TLSOptions.
  * Establishes secure SSL/TLS connections.
  * Refactoring of packstream, optimizing the encoding and decoding processes for efficient message handling.