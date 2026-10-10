CREATE OR REPLACE FUNCTION document_generation.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_consultation_document_updated_at
  BEFORE UPDATE ON document_generation.consultation_document
  FOR EACH ROW
  EXECUTE FUNCTION document_generation.set_updated_at();
