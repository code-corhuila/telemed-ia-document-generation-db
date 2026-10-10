CREATE INDEX idx_consultation_document_patient
  ON document_generation.consultation_document (patient_id);

CREATE INDEX idx_consultation_document_pending_or_error
  ON document_generation.consultation_document (status)
  WHERE status IN ('PENDING', 'ERROR');

CREATE INDEX idx_idempotency_key_document
  ON document_generation.idempotency_key (document_id);
