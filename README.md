# telemed-ia-document-generation-db

Database of the document-generation domain of TeleMed IA.
The -db repository of the document-service microservice.

## What this microservice does
It generates PDFs asynchronously from post-consultation summaries. It is
not a real-time HTTP generation service: it consumes the
PostConsultationSummaryGenerated event, queues the generation, runs it
with an internal worker, stores the reference to the binary in external
storage and publishes ConsultationPdfGenerated.

## Bounded context
- Domain: document-generation
- Microservice: document-service
- Consumes: PostConsultationSummaryGenerated (from consultation-service)
- Publishes: ConsultationPdfGenerated (consumed by patient-service)
- Main entity: consultation_document
- HU-016 (FR-31) main; HU-015 (FR-29, FR-30) related
- PostgreSQL schema: document_generation

## Domain invariants
- The PDF is generated only from a valid PostConsultationSummary.
- A patient downloads only the documents of their own consultations.
- A generation failure does NOT invalidate the completed consultation.
- A failed generation can be retried.
- document-generation neither owns nor modifies clinical information.
- storage_reference is never exposed to the client directly.

## What this database does NOT store
- No binaries (no bytea, no blob): the PDF goes to external storage
  (ADR-015 pending).
- No clinical information (diagnosis, medications): it lives in
  consultation-db.
- No real FKs to summary_id or patient_id: they live in other databases
  (ADR-004 database-per-service).

## Stack
- PostgreSQL 16-alpine
- Liquibase 4.31
- Docker Compose

## Where the database lives

Per **Anexo J**, the project has a single PostgreSQL instance owned by
`telemed-ia-infra-postgres`. This repository does **not** define a
Postgres container nor a volume: it only ships the Liquibase executor
that applies the `document_generation` schema to the shared instance.

- The instance, its volume, its users and its `pgcrypto` extension live
  in `telemed-ia-infra-postgres`.
- This repo owns the schema `document_generation` and its migrations.
- The executor uses its own Liquibase control tables
  (`databasechangelog_document_generation`,
  `databasechangeloglock_document_generation`) so it can coexist with
  other domains on the same instance (Anexo J.6).

### How to apply the migrations

From `telemed-ia-infra-postgres`:

```bash
./scripts/up.sh
docker compose --env-file env/dev.env --profile tooling \
  run --rm document-generation-db-migrate
```

### Contract with document-service

The application layer (`telemed-ia-document-generation-api`) must honor
two contracts that the schema cannot enforce on its own:

1. **Two-phase idempotency insert.** The `idempotency_key.document_id`
   column is nullable so the API can insert the key first (with
   `document_id = NULL`), then create the document and bind the key to
   it, all inside a single transaction. A second POST with the same key
   receives the cached response. The exact pattern is documented in the
   header comment of `01_ddl/04_alter/002_make_document_id_nullable.sql`.

2. **`request_hash` verification.** Before serving a cached response,
   the API must recompute the request hash and compare it against the
   stored `request_hash`. A mismatch means the same `Idempotency-Key`
   was reused with a different payload and must be rejected with
   `422 BUSINESS_RULE_VIOLATION` using the shared error envelope, not
   silently accepted. The common contract (numeral 5.3.5 of the standard)
   has no `409` code, so the API must not introduce one. The database
   stores the hash; it cannot compare it to an incoming value.

### Technical debt

- **`idempotency_key` retention.** The table has no TTL or pruning job
  yet. It grows with every POST, including successful ones. A future
  PR should add a scheduled cleanup (e.g., delete rows older than 90
  days) backed by an index on `created_at`. Registered as low-complexity
  debt.

- **`ON DELETE CASCADE` on `idempotency_key.document_id`.** If a
  `consultation_document` is deleted, the matching idempotency-key row
  disappears with it. This is intentional for storage hygiene but means
  the dedup record is not an audit trail. If an audit trail is ever
  required, it must live in a separate append-only table.

## Applicable ADRs
- ADR-003 bounded-contexts
- ADR-004 database-per-service
- ADR-010 clinical-document-separation
- ADR-011 message-broker
- ADR-012 service-naming-convention
- ADR-015 (pending) storage of the PDF binaries

(See code-corhuila/telemed-ia-docs, 05-architecture/decisions/records/)

## How to start it
This database is **not started from this repository**. See
"Where the database lives": the shared instance is started from
`telemed-ia-infra-postgres` with `./scripts/up.sh`, and the migrations
are applied from that same repository with the executor
`document-generation-db-migrate` (profile `tooling`).

## Governance
See code-corhuila/telemed-ia-docs.
Permanent branches: develop, qa, main.
Promotion between permanent branches with git cherry-pick -x.

## Roles

The `document_generation` schema is protected by two NOLOGIN roles that
carry the privileges:

- `document_generation_reader` — has `SELECT` on the tables of the schema.
- `document_generation_writer` — has `SELECT`, `INSERT` and `UPDATE`.

Both roles are created by `telemed-ia-infra-postgres` when the instance
starts (`postgres/init/01-instance.sh`). This repository declares the
privileges (`03_dcl/01_grants/001_grants.sql`), not the roles.

The application user, `document_generation_app`, is also created by the
infrastructure (with its password taken from a secret) and is a member of
both roles. The `-api` connects as `document_generation_app`, never as
the administrator.

This split follows Anexo J.4: roles belong to the whole instance (they
start with the domain prefix), so they live in the infrastructure
repository; schema-level privileges belong to the domain, so they live
here.

## Rebuild verification

As Anexo A requires, this repository includes a `db-ci.yml` workflow that
runs on every push to `develop`, `qa` and `main`, and on every pull
request to those branches. The workflow starts an empty Postgres 16
service, reproduces the infrastructure bootstrap (creates the `_app`,
`_reader` and `_writer` roles) and runs five steps:

1. `liquibase update` — the whole schema is built from an empty
   database.
2. `liquibase update` again — the second run must apply zero
   changesets. A non-zero count means the migrations are not
   incremental.
3. `liquibase rollback-count 999` — every changeset is rolled back in
   reverse order, leaving the database empty.
4. `liquibase update` — the schema is rebuilt from scratch after the
   full rollback.
5. Access control check — `document_generation_reader` cannot run
   `INSERT` on `consultation_document`.

A second job (`expected-count`) counts the changesets declared in every
`changelog.yaml` and compares that number with the value in
`changelog/expected-count.txt`. If they differ, the build fails.

To run the verification locally:

    docker network create platform       # once per machine
    cd ../telemed-ia-infra-postgres
    docker compose --env-file env/dev.env up -d --wait postgres
    docker compose --env-file env/dev.env --profile tooling \
      run --rm document-generation-db-migrate

Known limitation: the `expected-count` job compares the number of
changesets declared in the changelogs with `changelog/expected-count.txt`.
It detects that a changeset was added or removed, but not that two
changesets were swapped or renamed without changing the total. A stricter
check would compare the ordered list of changeset ids against a versioned
baseline; this is recorded as a follow-up and not implemented here.
