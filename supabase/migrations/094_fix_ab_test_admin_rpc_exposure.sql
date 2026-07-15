-- Migration 094: Fix anon/authenticated exposure of admin-only A/B testing RPCs.
--
-- admin_list_ab_tests() and admin_upsert_ab_test(...) (added in migration 086)
-- were only guarded by `IF current_role NOT IN ('postgres','service_role')`.
-- Inside a SECURITY DEFINER function, current_role always reflects the
-- function's OWNER (postgres), never the actual caller — so this check never
-- raises for anyone. The real protection is supposed to be REVOKE/GRANT, the
-- same pattern already applied correctly to get_funnel_summary and the other
-- admin_* RPCs in migration 077 — but 086 only added explicit GRANTs to
-- postgres/service_role and never revoked the implicit PUBLIC EXECUTE grant
-- that every new Postgres function gets by default. That default grant
-- cascades to anon and authenticated, leaving both RPCs fully callable by
-- anonymous callers.
--
-- Verified live before this fix (rolled back, no data changed):
--   SET ROLE anon; SELECT * FROM admin_list_ab_tests();        -- succeeded
--   SET ROLE anon; SELECT admin_upsert_ab_test(NULL,...);      -- succeeded, wrote a row
--
-- Impact: an unauthenticated caller could read internal test data and write/
-- activate arbitrary A/B test content (including the live landing-page hero
-- CTA and login-screen CTA button text).

REVOKE EXECUTE ON FUNCTION public.admin_list_ab_tests() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_upsert_ab_test(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.admin_list_ab_tests() TO postgres, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_ab_test(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) TO postgres, service_role;
