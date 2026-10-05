CREATE TABLE document_generation.consultation_document (
    document_id       uuid         NOT NULL DEFAULT gen_random_uuid(),
    summary_id        uuid         NOT NULL,
    patient_id        uuid         NOT NULL,
    format            text         NOT NULL,
    status            text         NOT NULL,
    storage_reference text,
    error_message     text,
    retry_count       integer      NOT NULL DEFAULT 0,
    generated_at      timestamptz,
    created_at        timestamptz  NOT NULL DEFAULT now(),

    CONSTRAINT pk_consultation_document
        PRIMARY KEY (document_id),

    CONSTRAINT chk_consultation_document_format
        CHECK (format = 'PDF'),

    CONSTRAINT chk_consultation_document_status
        CHECK (status IN ('PENDING', 'GENERATING', 'AVAILABLE', 'ERROR')),

    CONSTRAINT chk_consultation_document_retry_count
        CHECK (retry_count >= 0),

    CONSTRAINT chk_consultation_document_storage_reference_length
        CHECK (
            storage_reference IS NULL
            OR char_length(storage_reference) BETWEEN 1 AND 512
        ),

    CONSTRAINT chk_consultation_document_error_message_length
        CHECK (
            error_message IS NULL
            OR char_length(error_message) BETWEEN 1 AND 2000
        ),

    CONSTRAINT chk_consultation_document_storage_reference_state
        CHECK (
            (status = 'AVAILABLE' AND storage_reference IS NOT NULL)
            OR (status <> 'AVAILABLE' AND storage_reference IS NULL)
        ),

    CONSTRAINT chk_consultation_document_error_message_state
        CHECK (
            (status = 'ERROR' AND error_message IS NOT NULL)
            OR (status <> 'ERROR' AND error_message IS NULL)
        ),

    CONSTRAINT chk_consultation_document_generated_at_state
        CHECK (
            (status = 'AVAILABLE' AND generated_at IS NOT NULL)
            OR (status <> 'AVAILABLE' AND generated_at IS NULL)
        )
);
