-- -------------------------------------------------------------------------
-- Unique index on summary_id.
--
-- The business rule is: one PostConsultationSummary maps to exactly one
-- consultation_document. Retries transition the same row (ERROR ->
-- GENERATING -> AVAILABLE), they never insert a new one. Without this
-- index, a retried "generate PDF" call (client timeout, queue redelivery,
-- double click) can insert a second PENDING row for the same summary_id,
-- and two workers can independently drive each row to AVAILABLE with
-- different storage_reference values.
--
-- The other indexes (patient_id, partial on status, etc.) ship in PR #3.
-- -------------------------------------------------------------------------

CREATE UNIQUE INDEX idx_consultation_document_summary_unique
  ON document_generation.consultation_document (summary_id);
