ALTER TABLE document_generation.consultation_document
  ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();
