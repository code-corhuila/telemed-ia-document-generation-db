DROP TRIGGER IF EXISTS trg_consultation_document_status_transition
  ON document_generation.consultation_document;

DROP FUNCTION IF EXISTS document_generation.check_status_transition();
