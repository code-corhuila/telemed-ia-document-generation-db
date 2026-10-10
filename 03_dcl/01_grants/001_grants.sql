-- -------------------------------------------------------------------------
-- Privileges for the document_generation schema.
--
-- The roles document_generation_reader and document_generation_writer are
-- created by telemed-ia-infra-postgres during the instance bootstrap
-- (postgres/init/01-instance.sh). This changeset wires those roles to the
-- objects created by ddl-tables-001.
--
-- The application user (document_generation_app) is already a member of
-- both roles, so it inherits the privileges granted here.
-- -------------------------------------------------------------------------

GRANT SELECT
  ON document_generation.consultation_document
  TO document_generation_reader;

GRANT SELECT, INSERT, UPDATE
  ON document_generation.consultation_document
  TO document_generation_writer;

-- Ensure future tables created in this schema inherit the same grants.
ALTER DEFAULT PRIVILEGES IN SCHEMA document_generation
  GRANT SELECT ON TABLES TO document_generation_reader;

ALTER DEFAULT PRIVILEGES IN SCHEMA document_generation
  GRANT SELECT, INSERT, UPDATE ON TABLES TO document_generation_writer;
