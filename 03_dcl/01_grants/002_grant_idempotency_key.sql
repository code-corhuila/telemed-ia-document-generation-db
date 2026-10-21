-- -------------------------------------------------------------------------
-- Privileges on document_generation.idempotency_key.
--
-- dcl-grants-001 granted explicit privileges only on consultation_document.
-- Its ALTER DEFAULT PRIVILEGES statements apply to tables created AFTER it
-- runs; idempotency_key is created earlier (ddl-tables-003), so it was
-- left without grants for document_generation_reader and
-- document_generation_writer.
--
-- dcl-grants-001 is already applied in every environment and is not
-- edited (Anexo A, rule 12); this changeset adds the missing grants.
-- The writer needs SELECT, INSERT and UPDATE for the two-phase insert of
-- ddl-alter-002. No DELETE: key retention is registered technical debt.
-- -------------------------------------------------------------------------

GRANT SELECT
  ON document_generation.idempotency_key
  TO document_generation_reader;

GRANT SELECT, INSERT, UPDATE
  ON document_generation.idempotency_key
  TO document_generation_writer;
