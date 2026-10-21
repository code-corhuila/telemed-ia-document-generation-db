-- -------------------------------------------------------------------------
-- Role privilege test for the document_generation schema.
--
-- Contract (03_dcl/01_grants):
--   - document_generation_reader: SELECT on every table, nothing else.
--   - document_generation_writer: SELECT, INSERT, UPDATE on every table.
--
-- The check iterates over every table in the schema, so a table added by
-- a future changeset without its grants fails this test instead of
-- silently relying on ALTER DEFAULT PRIVILEGES (which never applies to
-- tables that already exist when it runs).
--
-- Run with: psql -v ON_ERROR_STOP=1 -f tests/sql/001_role_privileges.sql
-- -------------------------------------------------------------------------

DO $$
DECLARE
    gaps text;
BEGIN
    SELECT string_agg(format('%s (%s)', c.relname, missing), ', ' ORDER BY c.relname)
      INTO gaps
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN LATERAL (
          SELECT concat_ws(' ',
              CASE WHEN NOT has_table_privilege('document_generation_reader', c.oid, 'SELECT')
                   THEN 'reader:SELECT missing' END,
              CASE WHEN has_table_privilege('document_generation_reader', c.oid, 'INSERT')
                     OR has_table_privilege('document_generation_reader', c.oid, 'UPDATE')
                     OR has_table_privilege('document_generation_reader', c.oid, 'DELETE')
                   THEN 'reader:can write' END,
              CASE WHEN NOT has_table_privilege('document_generation_writer', c.oid, 'SELECT')
                   THEN 'writer:SELECT missing' END,
              CASE WHEN NOT has_table_privilege('document_generation_writer', c.oid, 'INSERT')
                   THEN 'writer:INSERT missing' END,
              CASE WHEN NOT has_table_privilege('document_generation_writer', c.oid, 'UPDATE')
                   THEN 'writer:UPDATE missing' END
          ) AS missing
      ) m
     WHERE n.nspname = 'document_generation'
       AND c.relkind = 'r'
       AND m.missing <> '';

    IF gaps IS NOT NULL THEN
        RAISE EXCEPTION 'Role privilege gaps in document_generation: %', gaps;
    END IF;

    RAISE NOTICE 'OK: reader and writer privileges are complete on every table';
END $$;

-- Behavioural check on idempotency_key: the writer role can run the
-- two-phase insert of ddl-alter-002; the reader role cannot. Every write
-- is rolled back.
BEGIN;
SET LOCAL ROLE document_generation_writer;
INSERT INTO document_generation.idempotency_key (idempotency_key, document_id, request_hash)
VALUES ('ci-privilege-test-key', NULL, 'ci-hash');
UPDATE document_generation.idempotency_key
   SET request_hash = 'ci-hash-2'
 WHERE idempotency_key = 'ci-privilege-test-key';
ROLLBACK;

DO $$
BEGIN
    SET LOCAL ROLE document_generation_reader;
    BEGIN
        INSERT INTO document_generation.idempotency_key (idempotency_key, document_id, request_hash)
        VALUES ('ci-privilege-test-key', NULL, 'ci-hash');
        RAISE EXCEPTION 'reader was able to INSERT into idempotency_key';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'OK: reader is blocked from INSERT on idempotency_key';
    END;
END $$;
