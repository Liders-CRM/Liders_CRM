-- Liders CRM — Migration 012: Server-side billing access enforcement
--
-- Problem: the trial/retention paywall (Billing.isExpired() / showPaywall())
-- is enforced ONLY in the browser. RLS on operational tables checks
-- tenant_id = get_my_tenant_id() but NOT billing status — so an
-- authenticated user whose trial has expired can still read/write their
-- tenant's leads/properties/tasks/etc. directly via the Supabase client
-- (e.g. from the browser console), bypassing the documented business rule
-- "data is preserved for 30 extra days, but the system cannot be used."
--
-- Fix: gate the existing "tenant isolation" policies on operational tables
-- with an additional tenant_access_active() check. This does NOT delete or
-- touch any data — it only blocks reads/writes once trial_ends_at has
-- passed and the tenant hasn't subscribed (mirrors Billing.isExpired()).
-- agent_users is intentionally left untouched — it's account/session
-- metadata needed for login and tenant resolution, not "using the CRM".

CREATE OR REPLACE FUNCTION tenant_access_active()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT CASE
    WHEN t.plan = 'cancelled' THEN false
    WHEN t.plan = 'trial'     THEN (t.trial_ends_at IS NULL OR now() <= t.trial_ends_at)
    ELSE true
  END
  FROM tenants t
  WHERE t.id = get_my_tenant_id();
$$;

-- Lock down EXECUTE — Postgres grants it to PUBLIC by default on CREATE
-- FUNCTION, which would let `anon` call it (it returns NULL safely for
-- anon since get_my_tenant_id() requires a session, but there's no reason
-- to expose it — same lesson as register_demo_agent in migration 013).
REVOKE EXECUTE ON FUNCTION public.tenant_access_active() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.tenant_access_active() FROM anon;
GRANT  EXECUTE ON FUNCTION public.tenant_access_active() TO authenticated;

DROP POLICY IF EXISTS "tenant isolation" ON pipeline_stages;
CREATE POLICY "tenant isolation" ON pipeline_stages
  FOR ALL
  USING       (tenant_id = get_my_tenant_id() AND tenant_access_active())
  WITH CHECK  (tenant_id = get_my_tenant_id() AND tenant_access_active());

DROP POLICY IF EXISTS "tenant isolation" ON leads;
CREATE POLICY "tenant isolation" ON leads
  FOR ALL
  USING       (tenant_id = get_my_tenant_id() AND tenant_access_active())
  WITH CHECK  (tenant_id = get_my_tenant_id() AND tenant_access_active());

DROP POLICY IF EXISTS "tenant isolation" ON properties;
CREATE POLICY "tenant isolation" ON properties
  FOR ALL
  USING       (tenant_id = get_my_tenant_id() AND tenant_access_active())
  WITH CHECK  (tenant_id = get_my_tenant_id() AND tenant_access_active());

DROP POLICY IF EXISTS "tenant isolation" ON tasks;
CREATE POLICY "tenant isolation" ON tasks
  FOR ALL
  USING       (tenant_id = get_my_tenant_id() AND tenant_access_active())
  WITH CHECK  (tenant_id = get_my_tenant_id() AND tenant_access_active());

DROP POLICY IF EXISTS "tenant isolation" ON showings;
CREATE POLICY "tenant isolation" ON showings
  FOR ALL
  USING       (tenant_id = get_my_tenant_id() AND tenant_access_active())
  WITH CHECK  (tenant_id = get_my_tenant_id() AND tenant_access_active());

DROP POLICY IF EXISTS "tenant isolation" ON activities;
CREATE POLICY "tenant isolation" ON activities
  FOR ALL
  USING       (tenant_id = get_my_tenant_id() AND tenant_access_active())
  WITH CHECK  (tenant_id = get_my_tenant_id() AND tenant_access_active());
