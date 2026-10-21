-- Revoke the privileges granted in 002_grant_idempotency_key.sql.

REVOKE SELECT, INSERT, UPDATE
  ON document_generation.idempotency_key
  FROM document_generation_writer;

REVOKE SELECT
  ON document_generation.idempotency_key
  FROM document_generation_reader;
