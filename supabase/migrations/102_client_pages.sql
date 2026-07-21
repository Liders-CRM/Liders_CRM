-- Migration 098: Page Builder — client_pages + public serving RPCs
--
-- New AI-driven page generation feature: a tenant generates a hosted, public,
-- shareable page (first use case: a referral-invite page wrapping an existing
-- lead_referrals `?lref=` token with AI-written intro copy). Generic enough
-- (page_type) to support future page types, but only 'referral_invite' is
-- built now.
--
-- Security model (mirrors 040/046/061/064): RLS enabled, no policies, access
-- only through SECURITY DEFINER RPCs.
--
-- Critical boundaries (see CLAUDE.md's mandatory-attribution requirement):
--   • The AI NEVER produces raw HTML — only structured fields (headline,
--     body_text, cta_label) rendered into a fixed static template
--     (page.html) whose "נוצר ע"י PLTO" footer is hardcoded in that
--     template's own markup, entirely outside anything AI-generated or
--     client-supplied can reach.
--   • cta_url is NEVER accepted from the caller — create_client_page()
--     derives it itself from the lead_referrals row the page belongs to.
--     Free-form URLs from AI/client input on a public, indexable page would
--     be an open-redirect/phishing vector.
--   • headline/body_text/cta_label are length-capped here (defense in depth
--     — page.html must still render them via textContent/escaping, never
--     innerHTML, on the frontend side).
--   • get_public_page()'s "tenant inactive" response is BYTE-IDENTICAL to
--     its "slug not found" response ({available:false}, no reason field) —
--     so nobody can probe whether a specific professional's subscription
--     lapsed by comparing responses. view_count is only incremented when
--     the gate passes.

CREATE TABLE IF NOT EXISTS client_pages (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  page_type          text NOT NULL CHECK (page_type IN ('referral_invite')),
  referral_id        uuid REFERENCES lead_referrals(id) ON DELETE SET NULL,
  slug               text UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(8), 'hex'),
  title              text,
  headline           text,
  body_text          text,
  cta_label          text,
  cta_url            text NOT NULL, -- frozen at creation time, not re-derived on read
  status             text NOT NULL DEFAULT 'published' CHECK (status IN ('published','archived')),
  view_count         integer NOT NULL DEFAULT 0,
  created_by_user_id uuid,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_client_pages_tenant ON client_pages(tenant_id, created_at DESC);

ALTER TABLE client_pages ENABLE ROW LEVEL SECURITY;
-- No policies on purpose: all access via SECURITY DEFINER RPCs below.

-- Flat weekly AI-generation quota for page copy, same shape as
-- lead_image_import_usage (084) — 5/week for every agent regardless of
-- plan tier, since page-builder access is deliberately open to all tenants
-- including trial (to maximize viral referral growth), gated only by cost
-- control, not by plan/marketing-addon.
CREATE TABLE IF NOT EXISTS public.page_copy_usage (
  id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  used_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_page_copy_usage_user_time ON public.page_copy_usage(user_id, used_at DESC);
ALTER TABLE public.page_copy_usage ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.check_and_increment_page_copy()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_email  text := auth.email();
  v_count  int;
  v_oldest timestamptz;
  v_limit  constant int := 5; -- flat 5/week across all plans, including trial
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'unauthenticated');
  END IF;

  IF v_email IN ('info@plto.app', 'elgrablidudu@gmail.com') THEN
    RETURN jsonb_build_object('allowed', true, 'plan', 'internal', 'admin', true);
  END IF;

  SELECT count(*), min(used_at) INTO v_count, v_oldest
  FROM page_copy_usage
  WHERE user_id = v_uid AND used_at > now() - interval '7 days';

  IF v_count >= v_limit THEN
    RETURN jsonb_build_object(
      'allowed', false, 'reason', 'weekly_limit',
      'used', v_count, 'limit', v_limit,
      'available_at', v_oldest + interval '7 days'
    );
  END IF;

  INSERT INTO page_copy_usage (user_id) VALUES (v_uid);
  RETURN jsonb_build_object('allowed', true, 'used', v_count + 1, 'limit', v_limit);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.check_and_increment_page_copy() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.check_and_increment_page_copy() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_page_copy_quota()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_email  text := auth.email();
  v_count  int;
  v_oldest timestamptz;
  v_limit  constant int := 5;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('used', 0, 'limit', v_limit); END IF;
  IF v_email IN ('info@plto.app', 'elgrablidudu@gmail.com') THEN
    RETURN jsonb_build_object('used', 0, 'limit', 999, 'admin', true);
  END IF;
  SELECT count(*), min(used_at) INTO v_count, v_oldest
  FROM page_copy_usage WHERE user_id = v_uid AND used_at > now() - interval '7 days';
  RETURN jsonb_build_object(
    'used', COALESCE(v_count, 0), 'limit', v_limit,
    'available_at', CASE WHEN COALESCE(v_count,0) >= v_limit THEN v_oldest + interval '7 days' ELSE NULL END
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_page_copy_quota() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_page_copy_quota() TO authenticated;

-- ── create_client_page(): authenticated, referral_invite pages wrap an existing lref token ──
CREATE OR REPLACE FUNCTION public.create_client_page(
  p_referral_id uuid,
  p_title       text,
  p_headline    text,
  p_body_text   text,
  p_cta_label   text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_ref       lead_referrals%ROWTYPE;
  v_slug      text;
  v_cta_url   text;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;

  -- Rate limit: 10 pages per user per 24h (matches create_lead_referral's threshold, 061)
  IF (SELECT count(*) FROM client_pages cp
      WHERE cp.created_by_user_id = auth.uid() AND cp.created_at > now() - interval '24 hours') >= 10 THEN
    RAISE EXCEPTION 'page_rate_limit';
  END IF;

  SELECT * INTO v_ref FROM lead_referrals WHERE id = p_referral_id AND from_tenant_id = v_tenant_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'referral not found'; END IF;

  -- cta_url is derived server-side from the referral's own token — never
  -- accepted as a parameter from the caller (open-redirect/phishing guard).
  v_cta_url := 'https://plto.app/?lref=' || v_ref.token;

  INSERT INTO client_pages (
    tenant_id, page_type, referral_id, title, headline, body_text, cta_label, cta_url, created_by_user_id
  ) VALUES (
    v_tenant_id, 'referral_invite', p_referral_id,
    left(coalesce(p_title, ''), 120),
    left(coalesce(p_headline, ''), 120),
    left(coalesce(p_body_text, ''), 600),
    left(coalesce(p_cta_label, 'הצטרפות'), 40),
    v_cta_url, auth.uid()
  )
  RETURNING slug INTO v_slug;

  RETURN jsonb_build_object('slug', v_slug);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.create_client_page(uuid,text,text,text,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.create_client_page(uuid,text,text,text,text) TO authenticated;

-- ── public_page_tenant_active(): anon-safe gate, parameterized (not session-based) ──
-- tenant_access_active() (012/043) cannot be reused: it resolves from
-- get_my_tenant_id(), i.e. the CALLER's own session, which is NULL for an
-- anonymous visitor. This duplicates the same active-plan logic explicitly
-- parameterized by tenant id (resolved server-side from the page's own row,
-- never from the caller's session) so the two functions can diverge safely
-- later without one silently affecting the other's security boundary.
CREATE OR REPLACE FUNCTION public.public_page_tenant_active(p_tenant_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
  SELECT CASE
    WHEN t.id IS NULL THEN false
    WHEN t.plan = 'cancelled' THEN false
    WHEN t.plan = 'trial' THEN (t.trial_ends_at IS NULL OR now() <= t.trial_ends_at)
    ELSE true
  END
  FROM (SELECT 1) x
  LEFT JOIN tenants t ON t.id = p_tenant_id;
$$;
REVOKE EXECUTE ON FUNCTION public.public_page_tenant_active(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.public_page_tenant_active(uuid) TO anon, authenticated;

-- ── get_public_page(): anon-callable, powers page.html ──
CREATE OR REPLACE FUNCTION public.get_public_page(p_slug text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $fn$
DECLARE
  v_page client_pages%ROWTYPE;
BEGIN
  SELECT * INTO v_page FROM client_pages WHERE slug = p_slug AND status = 'published';

  IF NOT FOUND OR NOT public.public_page_tenant_active(v_page.tenant_id) THEN
    -- Deliberately identical to "not found" — no reason field, so a lapsed
    -- tenant's subscription status can never be inferred by a visitor.
    RETURN jsonb_build_object('available', false);
  END IF;

  UPDATE client_pages SET view_count = view_count + 1 WHERE id = v_page.id;

  RETURN jsonb_build_object(
    'available', true,
    'title', v_page.title,
    'headline', v_page.headline,
    'body_text', v_page.body_text,
    'cta_label', v_page.cta_label,
    'cta_url', v_page.cta_url
  );
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.get_public_page(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_public_page(text) TO anon, authenticated;

-- ── admin_list_client_pages(): admin reporting view (mirrors get_saas_tenants_admin) ──
CREATE OR REPLACE FUNCTION public.admin_list_client_pages()
RETURNS TABLE (
  id uuid, tenant_name text, page_type text, slug text, status text,
  view_count integer, created_at timestamptz
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_email text := auth.email();
BEGIN
  IF v_email NOT IN ('info@plto.app','elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;

  RETURN QUERY
  SELECT cp.id, t.name, cp.page_type, cp.slug, cp.status, cp.view_count, cp.created_at
  FROM client_pages cp
  JOIN tenants t ON t.id = cp.tenant_id
  ORDER BY cp.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_list_client_pages() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.admin_list_client_pages() TO authenticated;

-- ── admin_archive_client_page(): let admin take a page down ──
CREATE OR REPLACE FUNCTION public.admin_archive_client_page(p_page_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_email text := auth.email();
BEGIN
  IF v_email NOT IN ('info@plto.app','elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;
  UPDATE client_pages SET status = 'archived', updated_at = now() WHERE id = p_page_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_archive_client_page(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.admin_archive_client_page(uuid) TO authenticated;
