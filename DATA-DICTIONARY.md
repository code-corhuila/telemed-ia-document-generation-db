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

## Roles

- `document_generation_app` — LOGIN, with password from
  `DOCUMENT_GENERATION_APP_PASSWORD`. Created by `telemed-ia-infra-postgres`.
- `document_generation_reader` — NOLOGIN. Granted `SELECT`.
- `document_generation_writer` — NOLOGIN. Granted `SELECT`, `INSERT`, `UPDATE`.
