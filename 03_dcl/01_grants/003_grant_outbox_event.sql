-- -------------------------------------------------------------------------
-- Privileges on document_generation.outbox_event.
--
-- The writer inserts events in the business transaction and the relay
-- updates published_at, publish_attempts and last_error. No DELETE:
-- pruning of published events is not part of this changeset.
-- -------------------------------------------------------------------------

GRANT SELECT
  ON document_generation.outbox_event
  TO document_generation_reader;

GRANT SELECT, INSERT, UPDATE
  ON document_generation.outbox_event
  TO document_generation_writer;
