-- ============================================================================
-- V202608211900__comment_on_penalties_table.sql
--
-- Migración trivial de prueba: verificar que
-- el pipeline de tres etapas (feature/* -> dev, PR -> gate, merge -> main)
-- aplica un cambio real de punta a punta. No altera datos ni estructura,
-- solo documenta la tabla.
-- ============================================================================

COMMENT ON TABLE penalties IS 'Multas asociadas a préstamos vencidos o dañados. Ver docs/dominio_de_negocio.md.';
