CREATE TABLE document_generation.idempotency_key (
    idempotency_key text         NOT NULL,
    document_id     uuid         NOT NULL,
    request_hash    text         NOT NULL,
    created_at      timestamptz  NOT NULL DEFAULT now(),

    CONSTRAINT pk_idempotency_key
        PRIMARY KEY (idempotency_key),

    CONSTRAINT chk_idempotency_key_length
        CHECK (char_length(idempotency_key) BETWEEN 8 AND 128),

    CONSTRAINT chk_idempotency_key_request_hash_length
        CHECK (char_length(request_hash) BETWEEN 1 AND 128)
);
