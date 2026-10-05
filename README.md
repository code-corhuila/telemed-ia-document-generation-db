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

## ADRs que aplican
- ADR-003 bounded-contexts
- ADR-004 database-per-service
- ADR-010 clinical-document-separation
- ADR-011 message-broker
- ADR-012 service-naming-convention
- ADR-015 (pendiente) storage de binarios PDF

(Ver code-corhuila/telemed-ia-docs, 05-architecture/decisions/records/)

## Cómo levantar
```bash
cp .env.example .env
docker compose -f deploy/compose.yml --env-file .env up -d
docker compose -f deploy/compose.yml --env-file .env run --rm document-generation-db-migrate
```

## Gobernanza
Ver code-corhuila/telemed-ia-docs.
Ramas permanentes: develop, qa, main.
Promoción entre permanentes por git cherry-pick -x.