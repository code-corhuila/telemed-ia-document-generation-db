# Data Dictionary — document_generation

Schema owner: `document_generation_app`
Schema: `document_generation`
Database engine: PostgreSQL 16

## Table: `document_generation.consultation_document`

Metadata of a PDF generated for a post-consultation summary.

| Column | Type | Nullable | Default | Constraints |
|---|---|---|---|---|
| `document_id` | `uuid` | NO | `gen_random_uuid()` | Primary key (`pk_consultation_document`) |
| `summary_id` | `uuid` | NO | — | Unique (`idx_consultation_document_summary_unique`). Reference to the source summary in `consultation-service`, enforced by contract, not FK. |
| `patient_id` | `uuid` | NO | — | Indexed (`idx_consultation_document_patient`). Reference to `patient-management`, enforced by contract. |
| `format` | `text` | NO | — | `CHECK (format = 'PDF')` (`chk_consultation_document_format`). |
| `status` | `text` | NO | — | `CHECK status IN ('PENDING','GENERATING','AVAILABLE','ERROR')` (`chk_consultation_document_status`). Transition guard trigger (`trg_consultation_document_status_transition`). |
| `storage_reference` | `text` | YES | — | Length 1–512 (`chk_consultation_document_storage_reference_length`). Must be NULL unless `status = 'AVAILABLE'` (`chk_consultation_document_storage_reference_state`). |
| `error_message` | `text` | YES | — | Length 1–2000 (`chk_consultation_document_error_message_length`). Must be NULL unless `status = 'ERROR'` (`chk_consultation_document_error_message_state`). |
| `retry_count` | `integer` | NO | `0` | `CHECK (retry_count >= 0)` (`chk_consultation_document_retry_count`). |
| `generated_at` | `timestamptz` | YES | — | Must be NULL unless `status = 'AVAILABLE'` (`chk_consultation_document_generated_at_state`). |
| `created_at` | `timestamptz` | NO | `now()` | — |
| `updated_at` | `timestamptz` | NO | `now()` | Refreshed on every UPDATE by `trg_consultation_document_updated_at`. |

### Legal status transitions

Enforced by the trigger `trg_consultation_document_status_transition`:

- `PENDING → GENERATING`
- `PENDING → ERROR`
- `GENERATING → AVAILABLE`
- `GENERATING → ERROR`
- `ERROR → GENERATING`

Any other transition raises `check_violation`.

## Table: `document_generation.idempotency_key`

Tracks the idempotency key with which a document was created, so the
`-api` can return the same response when the same key is replayed.

| Column | Type | Nullable | Default | Constraints |
|---|---|---|---|---|
| `idempotency_key` | `text` | NO | — | Primary key (`pk_idempotency_key`). Length 8–128 (`chk_idempotency_key_length`). |
| `document_id` | `uuid` | YES | — | FK to `consultation_document.document_id` (`fk_idempotency_key_document`, `ON DELETE CASCADE`). Indexed (`idx_idempotency_key_document`). Partial unique when NOT NULL (`idx_idempotency_key_document_unique`). NULL during the two-phase insert (see `01_ddl/04_alter/002_make_document_id_nullable.sql`). |
| `request_hash` | `text` | NO | — | Length 1–128 (`chk_idempotency_key_request_hash_length`). |
| `created_at` | `timestamptz` | NO | `now()` | — |

## Table: `document_generation.outbox_event`

Transactional outbox (numeral 5.3.11). The `-api` writes each event in the
same transaction as the `consultation_document` change that caused it; a
separate relay publishes the pending rows to the broker and marks them.

| Column | Type | Nullable | Default | Constraints |
|---|---|---|---|---|
| `event_id` | `uuid` | NO | `gen_random_uuid()` | Primary key (`pk_outbox_event`). Also the message id for consumer deduplication. |
| `aggregate_id` | `uuid` | NO | — | `document_id` that produced the event. Not a foreign key: the outbox is an append-only log of facts. |
| `event_type` | `text` | NO | — | `ConsultationPdfGenerated` only (`chk_outbox_event_event_type`), as named in `02-domain/domain-events.md`. |
| `event_version` | `integer` | NO | `1` | Envelope `version` (ADR-011), `>= 1` (`chk_outbox_event_event_version`). |
| `correlation_id` | `text` | NO | — | Envelope `correlationId` (ADR-011): the `X-Correlation-Id` of the request or consumed event that caused it. 1–128 characters (`chk_outbox_event_correlation_id_length`). |
| `payload` | `jsonb` | NO | — | Must be a JSON object (`chk_outbox_event_payload_object`). Its schema is the event contract in `telemed-ia-docs`. |
| `occurred_at` | `timestamptz` | NO | `now()` | — |
| `published_at` | `timestamptz` | YES | — | NULL while pending. Not earlier than `occurred_at` (`chk_outbox_event_published_after_occurred`). |
| `publish_attempts` | `integer` | NO | `0` | Counter, `>= 0` (`chk_outbox_event_publish_attempts`). |
| `last_error` | `text` | YES | — | Last relay error, 1–2000 characters (`chk_outbox_event_last_error_length`). |

**Indexes:** `idx_outbox_event_unpublished` on `(occurred_at) WHERE published_at IS NULL`, for the relay query.

## Roles

- `document_generation_app` — LOGIN, with password from
  `DOCUMENT_GENERATION_APP_PASSWORD`. Created by `telemed-ia-infra-postgres`.
- `document_generation_reader` — NOLOGIN. Granted `SELECT`.
- `document_generation_writer` — NOLOGIN. Granted `SELECT`, `INSERT`, `UPDATE`.

### Privileges per table

| Table | `document_generation_reader` | `document_generation_writer` | Granted by |
|---|---|---|---|
| `consultation_document` | `SELECT` | `SELECT`, `INSERT`, `UPDATE` | `dcl-grants-001` |
| `idempotency_key` | `SELECT` | `SELECT`, `INSERT`, `UPDATE` | `dcl-grants-002` |
| `outbox_event` | `SELECT` | `SELECT`, `INSERT`, `UPDATE` | `dcl-grants-003` |

Every table gets its grants explicitly in `03_dcl/01_grants/`. The
`ALTER DEFAULT PRIVILEGES` statements of `dcl-grants-001` only cover tables
created after that changeset runs, so they are not relied upon.
`tests/sql/001_role_privileges.sql` fails if any table in the schema is
missing these privileges, or if the reader can write.
