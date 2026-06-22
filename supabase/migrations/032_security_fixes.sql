-- Liders CRM — Migration 032: Security Fixes
--
-- Fixes three findings from the security audit:
--
-- FIX 1: update_tenant_integrations used `WHERE id = auth.uid()` but agent_users
--   stores the auth link in `auth_user_id`, not `id`. The two UUIDs are different:
--   `id` is the agent's own PK; `auth_user_id` is the FK to auth.users.
--   Result: the function always raised 'No tenant found for this user', silently
--   breaking Make.com webhook URL and WhatsApp number saving for all tenants.
--
-- FIX 2: tenants.industry CHECK constraint only allowed the old set of industry IDs
--   ('real_estate','sales','marketing','other'). The app frontend saves values like
--   'realestate','construction','interior_design','realestate_law','mortgages',
--   'property_insurance','staging_photo','realestate_tax'. Every DB update to
--   industry was silently failing (caught by try/catch, localStorage was fallback).
--   Fix: widen the constraint to the full set the frontend actually uses.
--
-- FIX 3: ai-proxy edge function had no explicit auth check inside the handler;
--   it relied entirely on Supabase gateway JWT validation. Added an explicit
--   authorization header check as defense-in-depth inside the function itself.
--   (see: supabase/functions/ai-proxy/index.ts)

-- ── FIX 1: correct column reference in update_tenant_integrations ─────────────
CREATE OR REPLACE FUNCTION update_tenant_integrations(
  p_make_webhook_url text DEFAULT NULL,
  p_whatsapp_number  text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  -- FIXED: use auth_user_id (FK to auth.users), not id (agent PK)
  SELECT tenant_id INTO v_tenant_id
  FROM agent_users
  WHERE auth_user_id = auth.uid()
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'No tenant found for this user';
  END IF;

  UPDATE tenants SET
    make_webhook_url = COALESCE(p_make_webhook_url, make_webhook_url),
    whatsapp_number  = COALESCE(p_whatsapp_number,  whatsapp_number),
    updated_at       = now()
  WHERE id = v_tenant_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION update_tenant_integrations(text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION update_tenant_integrations(text, text) FROM anon;
GRANT  EXECUTE ON FUNCTION update_tenant_integrations(text, text) TO authenticated;

-- ── FIX 1b: lock down get_my_tenant_id / get_my_agent_id helper functions ───
-- These were created in migration 020 without explicit REVOKE, so PostgreSQL's
-- default GRANT EXECUTE TO PUBLIC applies. Anon callers get NULL (safe), but
-- defense-in-depth: no reason to expose these to PUBLIC or anon.
REVOKE EXECUTE ON FUNCTION public.get_my_tenant_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_my_tenant_id() FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_my_tenant_id() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_my_agent_id() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_my_agent_id() FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_my_agent_id() TO authenticated;

-- ── FIX 2: widen industry CHECK constraint to match all frontend industry IDs ──
ALTER TABLE tenants DROP CONSTRAINT IF EXISTS tenants_industry_check;

ALTER TABLE tenants
  ADD CONSTRAINT tenants_industry_check
  CHECK (industry IN (
    -- real estate ecosystem (new set)
    'realestate',
    'construction',
    'interior_design',
    'realestate_law',
    'mortgages',
    'property_insurance',
    'staging_photo',
    'realestate_tax',
    -- legacy values (kept for backward compat with any existing rows)
    'real_estate',
    'sales',
    'marketing',
    'other'
  ));
