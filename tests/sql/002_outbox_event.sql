-- -------------------------------------------------------------------------
-- Schema test for document_generation.outbox_event (numeral 5.3.11).
--
-- Runs as document_generation_app under SET LOCAL ROLE
-- document_generation_writer, inside a transaction that is rolled back.
-- Each invalid row must be rejected by the named constraint.
--
-- Run with: psql -v ON_ERROR_STOP=1 -f tests/sql/002_outbox_event.sql
-- -------------------------------------------------------------------------

BEGIN;
SET LOCAL ROLE document_generation_writer;

-- A valid event is accepted with its defaults.
DO $$
DECLARE
    ev document_generation.outbox_event%ROWTYPE;
BEGIN
    INSERT INTO document_generation.outbox_event (aggregate_id, event_type, correlation_id, payload)
    VALUES (gen_random_uuid(), 'ConsultationPdfGenerated', 'corr-test-1', '{"documentId": "x"}')
    RETURNING * INTO ev;

    IF ev.event_id IS NULL OR ev.occurred_at IS NULL OR ev.event_version <> 1
       OR ev.published_at IS NOT NULL OR ev.publish_attempts <> 0 THEN
        RAISE EXCEPTION 'outbox_event defaults are wrong: %', row_to_json(ev);
    END IF;

    -- The relay marks the event as published.
    UPDATE document_generation.outbox_event
       SET published_at = now(), publish_attempts = publish_attempts + 1
     WHERE event_id = ev.event_id;

    RAISE NOTICE 'OK: valid event accepted and marked as published';
END $$;

-- Each invalid row must fail with the expected constraint name.
DO $$
DECLARE
    cases text[][] := ARRAY[
        ARRAY['chk_outbox_event_event_type',
              $q$INSERT INTO document_generation.outbox_event (aggregate_id, event_type, correlation_id, payload)
                 VALUES (gen_random_uuid(), 'UnknownEvent', 'c', '{}')$q$],
        ARRAY['chk_outbox_event_payload_object',
              $q$INSERT INTO document_generation.outbox_event (aggregate_id, event_type, correlation_id, payload)
                 VALUES (gen_random_uuid(), 'ConsultationPdfGenerated', 'c', '[1, 2]')$q$],
        ARRAY['chk_outbox_event_publish_attempts',
              $q$INSERT INTO document_generation.outbox_event (aggregate_id, event_type, correlation_id, payload, publish_attempts)
                 VALUES (gen_random_uuid(), 'ConsultationPdfGenerated', 'c', '{}', -1)$q$],
        ARRAY['chk_outbox_event_published_after_occurred',
              $q$INSERT INTO document_generation.outbox_event (aggregate_id, event_type, correlation_id, payload, occurred_at, published_at)
                 VALUES (gen_random_uuid(), 'ConsultationPdfGenerated', 'c', '{}', now(), now() - interval '1 minute')$q$],
        ARRAY['chk_outbox_event_correlation_id_length',
              $q$INSERT INTO document_generation.outbox_event (aggregate_id, event_type, correlation_id, payload)
                 VALUES (gen_random_uuid(), 'ConsultationPdfGenerated', '', '{}')$q$],
        ARRAY['chk_outbox_event_event_version',
              $q$INSERT INTO document_generation.outbox_event (aggregate_id, event_type, correlation_id, payload, event_version)
                 VALUES (gen_random_uuid(), 'ConsultationPdfGenerated', 'c', '{}', 0)$q$],
        ARRAY['chk_outbox_event_last_error_length',
              $q$INSERT INTO document_generation.outbox_event (aggregate_id, event_type, correlation_id, payload, last_error)
                 VALUES (gen_random_uuid(), 'ConsultationPdfGenerated', 'c', '{}', '')$q$]
    ];
    i int;
    violated text;
BEGIN
    FOR i IN 1 .. array_length(cases, 1) LOOP
        violated := NULL;
        BEGIN
            EXECUTE cases[i][2];
        EXCEPTION WHEN check_violation THEN
            GET STACKED DIAGNOSTICS violated = CONSTRAINT_NAME;
        END;
        IF violated IS DISTINCT FROM cases[i][1] THEN
            RAISE EXCEPTION 'expected % to reject the row, got %', cases[i][1], coalesce(violated, 'no error');
        END IF;
        RAISE NOTICE 'OK: % rejects the invalid row', cases[i][1];
    END LOOP;
END $$;

-- The relay query is served by the partial index.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
         WHERE schemaname = 'document_generation'
           AND indexname = 'idx_outbox_event_unpublished'
    ) THEN
        RAISE EXCEPTION 'idx_outbox_event_unpublished is missing';
    END IF;
    RAISE NOTICE 'OK: idx_outbox_event_unpublished exists';
END $$;

ROLLBACK;
