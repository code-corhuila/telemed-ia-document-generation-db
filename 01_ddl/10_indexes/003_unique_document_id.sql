-- -------------------------------------------------------------------------
-- Partial unique index on idempotency_key.document_id.
--
-- Ensures that once a key is bound to a document, no second key can
-- point to the same document. NULL document_id is allowed during the
-- two-phase insert (see ddl-alter-002); the partial predicate excludes
-- NULL so multiple in-flight keys with NULL are permitted, but only one
-- of them will survive long enough to bind to a document.
-- -------------------------------------------------------------------------

CREATE UNIQUE INDEX idx_idempotency_key_document_unique
  ON document_generation.idempotency_key (document_id)
  WHERE document_id IS NOT NULL;
