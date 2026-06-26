-- Migration 038: Re-assert table grants for authenticated role.
-- Defensive measure: ensures INSERT/UPDATE/DELETE on all public tables
-- are in place even if an earlier migration ran partially or a DB restore
-- reset grants.  Safe to run multiple times (GRANT is idempotent).

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
