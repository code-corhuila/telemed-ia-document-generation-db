-- WARNING: this rollback fails if any row currently has document_id = NULL.
-- The -api guarantees that document_id is filled within the same
-- transaction that inserts the key, so no NULL rows should persist. If
-- this rollback is ever needed, first run:
--   DELETE FROM document_generation.idempotency_key
--     WHERE document_id IS NULL;

ALTER TABLE document_generation.idempotency_key
  ALTER COLUMN document_id SET NOT NULL;
