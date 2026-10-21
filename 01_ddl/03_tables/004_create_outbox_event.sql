-- -------------------------------------------------------------------------
-- Transactional outbox for the events published by document-generation
-- (numeral 5.3.11 of the standard).
--
-- The -api writes the state change of consultation_document and the row
-- of its event in this table inside the SAME transaction. A separate relay
-- reads the unpublished rows, publishes them to the broker and sets
-- published_at. Publishing right after the commit would lose the event if
-- the process died between the two actions.
--
-- aggregate_id is the document_id that produced the event. It is
-- deliberately NOT a foreign key: the outbox is an append-only log of
-- facts, and an event that already happened must neither block nor be
-- removed by a later change to the document row.
--
-- event_id, event_type, occurred_at, correlation_id, event_version and
-- payload are the event envelope fields of ADR-011 (Message Structure),
-- so the relay can publish a row without reading any other table.
--
-- event_type is a closed set (CHECK, never ENUM: Anexo A, rule 5). Only
-- ConsultationPdfGenerated is published today; a new event type is a new
-- changeset that replaces the CHECK.
-- -------------------------------------------------------------------------

CREATE TABLE document_generation.outbox_event (
    event_id         uuid         NOT NULL DEFAULT gen_random_uuid(),
    aggregate_id     uuid         NOT NULL,
    event_type       text         NOT NULL,
    event_version    integer      NOT NULL DEFAULT 1,
    correlation_id   text         NOT NULL,
    payload          jsonb        NOT NULL,
    occurred_at      timestamptz  NOT NULL DEFAULT now(),
    published_at     timestamptz,
    publish_attempts integer      NOT NULL DEFAULT 0,
    last_error       text,

    CONSTRAINT pk_outbox_event
        PRIMARY KEY (event_id),

    CONSTRAINT chk_outbox_event_event_type
        CHECK (event_type IN ('ConsultationPdfGenerated')),

    CONSTRAINT chk_outbox_event_event_version
        CHECK (event_version >= 1),

    CONSTRAINT chk_outbox_event_correlation_id_length
        CHECK (char_length(correlation_id) BETWEEN 1 AND 128),

    CONSTRAINT chk_outbox_event_payload_object
        CHECK (jsonb_typeof(payload) = 'object'),

    CONSTRAINT chk_outbox_event_publish_attempts
        CHECK (publish_attempts >= 0),

    CONSTRAINT chk_outbox_event_published_after_occurred
        CHECK (published_at IS NULL OR published_at >= occurred_at),

    CONSTRAINT chk_outbox_event_last_error_length
        CHECK (last_error IS NULL OR char_length(last_error) BETWEEN 1 AND 2000)
);
