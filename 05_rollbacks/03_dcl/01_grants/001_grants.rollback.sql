-- Revoke the privileges granted in 001_grants.sql and remove the default
-- privileges for the schema.

ALTER DEFAULT PRIVILEGES IN SCHEMA document_generation
  REVOKE SELECT ON TABLES FROM document_generation_reader;

ALTER DEFAULT PRIVILEGES IN SCHEMA document_generation
  REVOKE SELECT, INSERT, UPDATE ON TABLES FROM document_generation_writer;

REVOKE SELECT, INSERT, UPDATE
  ON document_generation.consultation_document
  FROM document_generation_writer;

REVOKE SELECT
  ON document_generation.consultation_document
  FROM document_generation_reader;
