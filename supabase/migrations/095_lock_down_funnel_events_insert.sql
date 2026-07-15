-- Migration 095: Remove the wide-open funnel_events INSERT policies.
--
-- funnel_events_insert_anon / funnel_events_insert_auth (from migration
-- funnel_events_cro) allowed any anon/authenticated caller to INSERT
-- arbitrary rows directly via PostgREST, with no validation, bypassing the
-- track_funnel_event() RPC's event_name whitelist/length checks entirely.
-- This was flagged in a prior QA pass (11/7) as a storage-inflation vector,
-- pending confirmation that no code relies on the direct-REST path before
-- tightening it.
--
-- Verified before this fix: track_funnel_event() is SECURITY DEFINER and
-- inserts directly, so it does not depend on these policies at all (RLS is
-- bypassed inside SECURITY DEFINER functions). Grepped index.html,
-- landing.html and admin.html for any `.from('funnel_events')` client call —
-- none exist; every write goes through the RPC. Safe to drop.

DROP POLICY IF EXISTS "funnel_events_insert_anon" ON public.funnel_events;
DROP POLICY IF EXISTS "funnel_events_insert_auth" ON public.funnel_events;
