-- Migration 043: Fix admin bypass mismatch between frontend and RLS
--
-- Bug: index.html's TrialGate.isExpired() whitelists the two admin emails
-- (liders.crm@gmail.com, elgrablidudu@gmail.com) so the UI never shows the
-- paywall for them — but the DB-side tenant_access_active() function (used
-- by the tenant-isolation RLS policy on leads/properties/tasks/showings/
-- activities/pipeline_stages) only checks plan/trial_ends_at and has no
-- such bypass. Once an admin's own trial tenant lapses past 30 days, the
-- UI keeps working but every INSERT/UPDATE is silently rejected by RLS —
-- "new row violates row-level security policy" on both lead and property
-- saves (same underlying cause, same error shape).
--
-- Fix: give tenant_access_active() the same admin bypass as the frontend.

CREATE OR REPLACE FUNCTION public.tenant_access_active()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
  SELECT CASE
    WHEN auth.email() IN ('liders.crm@gmail.com', 'elgrablidudu@gmail.com') THEN true
    WHEN t.plan = 'cancelled' THEN false
    WHEN t.plan = 'trial'     THEN (t.trial_ends_at IS NULL OR now() <= t.trial_ends_at)
    ELSE true
  END
  FROM tenants t WHERE t.id = get_my_tenant_id();
$$;
