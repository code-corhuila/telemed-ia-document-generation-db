ALTER TABLE document_generation.idempotency_key
  ADD CONSTRAINT fk_idempotency_key_document
  FOREIGN KEY (document_id)
  REFERENCES document_generation.consultation_document (document_id)
  ON DELETE CASCADE;
