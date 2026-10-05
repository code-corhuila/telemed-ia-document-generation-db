-- -------------------------------------------------------------------------
-- Extend the legal state-transition list with PENDING -> ERROR.
--
-- Reason: a validation error on the source consultation summary can be
-- detected before any generation attempt. Forcing the caller to flip
-- through GENERATING when no work was done is artificial. PENDING -> ERROR
-- is now a legal direct transition.
--
-- Implementation: CREATE OR REPLACE FUNCTION redefines the transition
-- guard in place. The existing trigger (trg_consultation_document_status_transition)
-- keeps pointing at the function, so no trigger drop/create is needed.
-- -------------------------------------------------------------------------

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
        (OLD.status = 'PENDING'    AND NEW.status = 'ERROR')      OR
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
