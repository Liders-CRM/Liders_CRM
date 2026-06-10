-- Liders CRM — Migration 014: Real per-tenant self-provisioning
--
-- Problem: every signup currently lands in the single shared DEMO_TENANT via
-- register_demo_agent() (migration 010/013) — there is no real multi-tenant
-- onboarding. This means (a) all new users see the same seeded demo data,
-- (b) trial countdown is meaningless (everyone shares one trial_ends_at),
-- and (c) cross-customer data isolation — the entire premise of the product —
-- doesn't actually exist for organic signups.
--
-- This migration adds the missing piece: a SECURITY DEFINER bootstrap that
-- gives every brand-new auth user their OWN tenant (with its own pipeline
-- stages and a 30-day trial clock starting at registration), while remaining
-- a no-op for users who already belong to a tenant (so existing demo-tenant
-- users, including the demo@liders.co.il account, are completely unaffected).
--
-- Bonus fix: tenants had RLS enabled with policies for `service_role` and
-- `anon` only — `authenticated` had no policy at all, so the direct
-- `.from('tenants').select(...)` in DB.loadAll() always returned zero rows
-- and State.tenant silently fell back to a hardcoded default WITHOUT
-- trial_ends_at. Net effect: Billing.daysLeft() always returned its 30-day
-- fallback — the trial banner never actually counted down. We add a narrow
-- SELECT-only policy scoped to the caller's own tenant row.

-- ─────────────────────────────────────────────
-- 1. Let agents read (but not write) their own tenant row directly.
--    SELECT only — billing fields (plan, trial_ends_at, stripe_*) must stay
--    writable solely through service-role/webhook paths and the narrow
--    update_tenant_profile() RPC below, never via a direct authenticated
--    UPDATE (that would let a tenant grant itself a paid plan / extend trial).
-- ─────────────────────────────────────────────
CREATE POLICY "agents read own tenant" ON tenants
  FOR SELECT
  TO authenticated
  USING (id = get_my_tenant_id());

-- ─────────────────────────────────────────────
-- 2. ensure_agent_and_tenant() — idempotent signup bootstrap
--
--    Returning user (already has an agent_users row): returns their existing
--    {agent_id, tenant_id} untouched — identical behavior to today.
--
--    Brand-new user: creates a fresh tenant (trial_ends_at = now() + 30 days,
--    i.e. the trial clock starts at THIS registration, not at some shared
--    demo-tenant timestamp), seeds the standard 5-stage pipeline, and
--    inserts the caller as that tenant's `owner`.
--
--    Mirrors the auth-binding hardening from migration 013: identity is
--    derived from auth.uid()/auth.email() (the verified JWT), never from
--    client-supplied parameters — p_agency_name/p_name only ever seed
--    display fields on a row scoped to the caller's own new tenant, so
--    there is no cross-account write surface.
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ensure_agent_and_tenant(p_agency_name text DEFAULT NULL, p_name text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid          uuid := auth.uid();
  v_email        text := auth.email();
  v_agent_id     uuid;
  v_tenant_id    uuid;
  v_slug         text;
  v_display_name text;
  v_agency_name  text;
BEGIN
  IF v_uid IS NULL OR v_email IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  -- Idempotent fast path: this auth identity already has a home.
  SELECT id, tenant_id INTO v_agent_id, v_tenant_id
  FROM agent_users WHERE auth_user_id = v_uid LIMIT 1;

  IF v_agent_id IS NOT NULL THEN
    RETURN jsonb_build_object('agent_id', v_agent_id, 'tenant_id', v_tenant_id, 'is_new', false);
  END IF;

  v_display_name := coalesce(nullif(trim(p_name), ''), split_part(v_email, '@', 1));
  v_agency_name  := coalesce(nullif(trim(p_agency_name), ''), 'הסוכנות של ' || v_display_name);

  -- Random, collision-proof slug — display name lives in `name`; `slug` is
  -- just an internal unique key (not used for routing in this app today).
  v_slug := 'agency-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12);

  INSERT INTO tenants (name, slug, plan, trial_ends_at, billing_email)
  VALUES (v_agency_name, v_slug, 'trial', now() + interval '30 days', v_email)
  RETURNING id INTO v_tenant_id;

  INSERT INTO pipeline_stages (tenant_id, name, color, order_idx, is_terminal, is_won) VALUES
    (v_tenant_id, 'ליד חדש',     '#94A3B8', 1, false, false),
    (v_tenant_id, 'בקשר',        '#3B82F6', 2, false, false),
    (v_tenant_id, 'ביקור נקבע', '#8B5CF6', 3, false, false),
    (v_tenant_id, 'הצעה הוגשה', '#F59E0B', 4, false, false),
    (v_tenant_id, 'סגירה ✓',     '#10B981', 5, true,  true);

  INSERT INTO agent_users (tenant_id, auth_user_id, name, email, role)
  VALUES (v_tenant_id, v_uid, v_display_name, v_email, 'owner')
  RETURNING id INTO v_agent_id;

  RETURN jsonb_build_object('agent_id', v_agent_id, 'tenant_id', v_tenant_id, 'is_new', true);
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.ensure_agent_and_tenant(text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.ensure_agent_and_tenant(text, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.ensure_agent_and_tenant(text, text) TO authenticated;

-- ─────────────────────────────────────────────
-- 3. update_tenant_profile() — narrow, owner-only profile editing
--
--    Lets the onboarding wizard persist the agency name/phone/city the
--    tenant enters (today it only writes to localStorage — cosmetic only).
--    Deliberately touches ONLY non-billing display columns. plan,
--    trial_ends_at, stripe_customer_id, stripe_subscription_id and
--    plan_expires_at are never reachable here — granting a broad
--    "update your own tenant row" policy/RPC would let any tenant extend
--    its own trial or self-assign a paid plan.
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_tenant_profile(p_name text, p_phone text DEFAULT NULL, p_city text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_tenant_id uuid;
  v_role      text;
BEGIN
  SELECT tenant_id, role INTO v_tenant_id, v_role
  FROM agent_users WHERE auth_user_id = auth.uid() LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'no tenant for current user';
  END IF;
  IF v_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'insufficient permissions';
  END IF;
  IF p_name IS NULL OR trim(p_name) = '' THEN
    RAISE EXCEPTION 'agency name is required';
  END IF;

  UPDATE tenants
  SET name  = trim(p_name),
      phone = nullif(trim(coalesce(p_phone, '')), ''),
      city  = nullif(trim(coalesce(p_city, '')), '')
  WHERE id = v_tenant_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.update_tenant_profile(text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_tenant_profile(text, text, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.update_tenant_profile(text, text, text) TO authenticated;
