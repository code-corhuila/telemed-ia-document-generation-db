# telemed-ia-document-generation-db

Base de datos del dominio document-generation de TeleMed IA.
Repositorio -db del microservicio document-service.

## Qué hace este microservicio
Genera PDFs asíncronos a partir de resúmenes post-consulta. No es un
servicio HTTP de generación en tiempo real: consume el evento
PostConsultationSummaryGenerated, encola la generación, la ejecuta con
un worker interno, guarda la referencia del binario en un storage
externo y publica ConsultationPdfGenerated.

## Bounded context
- Dominio: document-generation
- Microservicio: document-service
- Consume: PostConsultationSummaryGenerated (de consultation-service)
- Publica: ConsultationPdfGenerated (lo consume patient-service)
- Entidad principal: consultation_document
- HU-016 (RF-31) principal; HU-015 (RF-29, RF-30) relacionada
- Schema PostgreSQL: document_generation

## Invariantes del dominio
- El PDF solo se genera desde un PostConsultationSummary válido.
- Un paciente solo descarga documentos de sus propias consultas.
- Un fallo de generación NO invalida la consulta completada.
- Una generación fallida puede reintentarse.
- document-generation no posee ni modifica información clínica.
- storage_reference nunca se expone al cliente directamente.

## Lo que NO guarda esta BD
- No binarios (no bytea, no blob): el PDF va a storage externo
  (ADR-015 pendiente).
- No información clínica (diagnóstico, medicamentos): vive en
  consultation-db.
- No FK reales a summary_id ni patient_id: viven en otras bases
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
   `409 CONFLICT`, not silently accepted. The database stores the hash;
   it cannot compare it to an incoming value.

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

## ADRs que aplican
- ADR-003 bounded-contexts
- ADR-004 database-per-service
- ADR-010 clinical-document-separation
- ADR-011 message-broker
- ADR-012 service-naming-convention
- ADR-015 (pendiente) storage de binarios PDF

(Ver code-corhuila/telemed-ia-docs, 05-architecture/decisions/records/)

## Cómo levantar
Esta base de datos **no se levanta desde este repositorio**. Ver
"Where the database lives": la instancia compartida se levanta desde
`telemed-ia-infra-postgres` con `./scripts/up.sh`, y las migraciones
se aplican desde ese mismo repositorio con el executor
`document-generation-db-migrate` (perfil `tooling`).

## Gobernanza
Ver code-corhuila/telemed-ia-docs.
Ramas permanentes: develop, qa, main.
Promoción entre permanentes por git cherry-pick -x.

## Roles

El schema `document_generation` está protegido por dos roles NOLOGIN que
cargan los permisos:

- `document_generation_reader` — tiene `SELECT` sobre las tablas del schema.
- `document_generation_writer` — tiene `SELECT`, `INSERT` y `UPDATE`.

Ambos roles los crea `telemed-ia-infra-postgres` durante el arranque de
la instancia (`postgres/init/01-instance.sh`). Este repositorio declara
los permisos (`03_dcl/01_grants/001_grants.sql`), no los roles.

El usuario de aplicación, `document_generation_app`, también lo crea la
infraestructura (con la contraseña tomada de un secreto) y es miembro de
ambos roles. El `-api` se conecta con `document_generation_app`, nunca
con el administrador.

Esta división sigue el Anexo J.4: los roles son de toda la instancia
(empiezan con el prefijo del dominio), por eso viven en el repositorio de
infraestructura; los permisos a nivel de schema son propios del dominio,
por eso viven aquí.

## Verificación de reconstrucción

Según el Anexo A, este repositorio incluye un workflow `db-ci.yml` que
se ejecuta en cada push a `develop`, `qa` y `main`, y en cada pull
request hacia esas ramas. El workflow levanta un servicio Postgres 16
vacío, replica el arranque de la infraestructura (crea los roles `_app`,
`_reader` y `_writer`) y ejecuta cinco pasos:

1. `liquibase update` — el schema completo se construye desde una base
   de datos vacía.
2. `liquibase update` de nuevo — la segunda ejecución debe aplicar cero
   changesets. Un conteo distinto de cero indica que las migraciones no
   son incrementales.
3. `liquibase rollback-count 999` — todos los changesets se revierten en
   orden inverso, dejando la base de datos vacía.
4. `liquibase update` — el schema se reconstruye desde cero tras el
   rollback completo.
5. Verificación de control de acceso — `document_generation_reader` no
   puede ejecutar `INSERT` sobre `consultation_document`.

Un segundo job (`expected-count`) cuenta los changesets declarados en
cada `changelog.yaml` y compara ese número con el valor de
`changelog/expected-count.txt`. Si no coinciden, el build falla.

Para ejecutar la verificación localmente:

    docker network create platform       # once per machine
    cd ../telemed-ia-infra-postgres
    docker compose --env-file env/dev.env up -d --wait postgres
    docker compose --env-file env/dev.env --profile tooling \
      run --rm document-generation-db-migrate

Limitación conocida: el job `expected-count` compara el número de
changesets declarados en los changelogs con `changelog/expected-count.txt`.
Detecta que se agregue o elimine un changeset, pero no que dos changesets
se intercambien o se renombren sin cambiar el total. Un control más
estricto compararía la lista ordenada de ids de changesets contra una
línea base versionada; queda registrado como seguimiento y no se
implementa aquí.