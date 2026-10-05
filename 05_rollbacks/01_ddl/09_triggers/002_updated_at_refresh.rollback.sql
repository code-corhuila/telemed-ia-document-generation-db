DROP TRIGGER IF EXISTS trg_consultation_document_updated_at
  ON document_generation.consultation_document;

DROP FUNCTION IF EXISTS document_generation.set_updated_at();
