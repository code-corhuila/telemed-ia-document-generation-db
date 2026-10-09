CREATE OR REPLACE FUNCTION document_generation.check_status_transition()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    IF NOT (
        (OLD.status = 'PENDING'    AND NEW.status = 'GENERATING') OR
        (OLD.status = 'GENERATING' AND NEW.status = 'AVAILABLE')  OR
        (OLD.status = 'GENERATING' AND NEW.status = 'ERROR')      OR
        (OLD.status = 'ERROR'      AND NEW.status = 'GENERATING')
    ) THEN
        RAISE EXCEPTION
            'Invalid consultation_document status transition: % -> %',
            OLD.status, NEW.status
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_consultation_document_status_transition
  BEFORE UPDATE ON document_generation.consultation_document
  FOR EACH ROW
  EXECUTE FUNCTION document_generation.check_status_transition();
