-- Revoke the privileges granted in 003_grant_outbox_event.sql.

REVOKE SELECT, INSERT, UPDATE
  ON document_generation.outbox_event
  FROM document_generation_writer;

REVOKE SELECT
  ON document_generation.outbox_event
  FROM document_generation_reader;
