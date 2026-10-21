-- -------------------------------------------------------------------------
-- Index for the outbox relay query:
--
--   SELECT ... FROM document_generation.outbox_event
--    WHERE published_at IS NULL
--    ORDER BY occurred_at
--    LIMIT <batch size>
--    FOR UPDATE SKIP LOCKED;
--
-- Partial on published_at IS NULL so it only holds the pending events and
-- stays small as published rows accumulate.
--
-- Created without CONCURRENTLY on purpose: outbox_event is created empty by
-- ddl-tables-004 in this same release, so there are no rows or writers to
-- block (Anexo A, rule 14 applies to tables that already hold data).
-- -------------------------------------------------------------------------

CREATE INDEX idx_outbox_event_unpublished
  ON document_generation.outbox_event (occurred_at)
  WHERE published_at IS NULL;
