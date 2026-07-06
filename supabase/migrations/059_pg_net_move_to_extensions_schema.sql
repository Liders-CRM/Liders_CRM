-- Migration 059: move pg_net out of the public schema (Supabase security lint 0014).
-- ALTER EXTENSION ... SET SCHEMA is not supported for pg_net, so drop + recreate.
-- The net.http_post() calls in the daily-digest cron job (057/058) are unaffected -
-- pg_net always exposes its functions under the fixed `net` schema regardless of
-- which schema owns the extension's own catalog entry.
DROP EXTENSION pg_net;
CREATE EXTENSION pg_net SCHEMA extensions;
