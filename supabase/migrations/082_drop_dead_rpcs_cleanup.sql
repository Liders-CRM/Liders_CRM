-- PLTO — Migration 082: Drop unused RPCs found in pre-launch cleanup sweep
--
-- Two functions confirmed to have zero call sites anywhere in the client
-- (index.html/admin.html/landing.html) and no dependents in pg_proc:
--
--   - get_active_ab_tests(): the CRO A/B-test admin flow
--     (admin_list_ab_tests/admin_upsert_ab_test, both still in use) lets an
--     admin define tests, but the function that would serve an active
--     variant to a real visitor on landing.html was never wired in. Half of
--     a feature, not a working one — safe to drop and trivial to
--     re-implement later if the variant-serving side gets built.
--   - cancel_client_consent(uuid): respond_client_consent (approve/decline)
--     is the flow actually used; the "referrer cancels their own pending
--     request" path has no UI entry point anywhere.
--
-- community_jokes (table + 8 RPCs + the auto-approve-daily-jokes cron) was
-- reviewed in the same sweep and found equally unused, but is intentionally
-- KEPT — the owner wants to finish it properly later as a future feature
-- once there's a real user base to seed it with jokes. Not touched here.
--
-- get_trial_expiry_candidates() looked unused from the repo alone but was
-- confirmed live via the Make.com "PLTO — Trial Expiry Notifications"
-- scenario (calls it daily over REST). Not touched here.
-- ─────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.get_active_ab_tests();
DROP FUNCTION IF EXISTS public.cancel_client_consent(uuid);
