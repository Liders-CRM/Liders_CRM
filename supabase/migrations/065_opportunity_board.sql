-- Migration 065: National Opportunity Board (לוח הזדמנויות והפניות ארצי)
--
-- Lets users find commission partners OUTSIDE their usual area: a user
-- publishes an anonymous opportunity ("מחפש מעצבת פנים באזור חיפה לפרויקט
-- קבלן, עמלה מובטחת"), relevant users in that region/vertical apply, and the
-- publisher picks one — which creates a DIRECTED lead_referral that continues
-- through the exact same pipeline as any referral: client consent (064) →
-- commission agreement signature (063) → lead lands in the partner's pipeline.
--
-- Anonymity: the board never exposes the publisher's name/business — only
-- their vertical + region. Names are revealed mutually only after selection.
--
-- Security model (mirrors 061/063/064): RLS enabled with zero policies,
-- SECURITY DEFINER RPCs only, server-derived tenant identity, rate limits.

-- ── 1. Structured region on tenants (8 fixed regions) ─────────────────────

ALTER TABLE tenants ADD COLUMN IF NOT EXISTS region text;
ALTER TABLE tenants DROP CONSTRAINT IF EXISTS tenants_region_check;
ALTER TABLE tenants ADD CONSTRAINT tenants_region_check CHECK (
  region IS NULL OR region IN
  ('north','haifa','sharon','center','telaviv','jerusalem','shfela','south')
);
-- Keep 017's explicit column-list SELECT grant coherent
GRANT SELECT (region) ON tenants TO authenticated;

-- update_tenant_profile gains p_region (signature change → drop + recreate)
DROP FUNCTION IF EXISTS public.update_tenant_profile(text,text,text);
CREATE OR REPLACE FUNCTION public.update_tenant_profile(
  p_name   text,
  p_phone  text DEFAULT NULL,
  p_city   text DEFAULT NULL,
  p_region text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE v_tenant_id uuid; v_role text;
BEGIN
  SELECT tenant_id, role INTO v_tenant_id, v_role
    FROM agent_users WHERE auth_user_id = auth.uid() LIMIT 1;
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;
  IF v_role NOT IN ('owner','admin') THEN RAISE EXCEPTION 'insufficient permissions'; END IF;
  IF p_name IS NULL OR trim(p_name) = '' THEN RAISE EXCEPTION 'agency name is required'; END IF;
  IF p_region IS NOT NULL AND p_region NOT IN
     ('north','haifa','sharon','center','telaviv','jerusalem','shfela','south') THEN
    RAISE EXCEPTION 'invalid_region';
  END IF;
  UPDATE tenants SET
    name   = trim(p_name),
    phone  = nullif(trim(coalesce(p_phone,'')), ''),
    city   = nullif(trim(coalesce(p_city,'')), ''),
    region = p_region
  WHERE id = v_tenant_id;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.update_tenant_profile(text,text,text,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_tenant_profile(text,text,text,text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.update_tenant_profile(text,text,text,text) TO authenticated;

-- ── 2. Tables ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS partner_opportunities (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  created_by       uuid NOT NULL,
  title            text NOT NULL CHECK (char_length(title) BETWEEN 5 AND 120),
  description      text CHECK (description IS NULL OR char_length(description) <= 1000),
  target_vertical  text NOT NULL
                   CHECK (target_vertical IN ('realestate','realestate_lawyer','interior')),
  region           text NOT NULL CHECK (region IN
                   ('north','haifa','sharon','center','telaviv','jerusalem','shfela','south')),
  city             text,
  commission_type  text NOT NULL DEFAULT 'none'
                   CHECK (commission_type IN ('none','percent','fixed')),
  commission_value numeric(10,2),
  status           text NOT NULL DEFAULT 'open'
                   CHECK (status IN ('open','matched','closed','expired','removed')),
  selected_application_id uuid,  -- FK added below (table order)
  created_at       timestamptz NOT NULL DEFAULT now(),
  expires_at       timestamptz NOT NULL DEFAULT now() + interval '30 days',
  CONSTRAINT partner_opportunities_commission_check CHECK (
    (commission_type = 'none'    AND commission_value IS NULL) OR
    (commission_type = 'percent' AND commission_value > 0 AND commission_value <= 50) OR
    (commission_type = 'fixed'   AND commission_value > 0 AND commission_value <= 1000000)
  )
);

CREATE TABLE IF NOT EXISTS opportunity_applications (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  opportunity_id      uuid NOT NULL REFERENCES partner_opportunities(id) ON DELETE CASCADE,
  applicant_tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  applicant_user_id   uuid NOT NULL,
  message             text CHECK (message IS NULL OR char_length(message) <= 500),
  status              text NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending','selected','rejected','withdrawn')),
  created_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (opportunity_id, applicant_tenant_id)
);

ALTER TABLE partner_opportunities
  DROP CONSTRAINT IF EXISTS partner_opportunities_selected_app_fkey;
ALTER TABLE partner_opportunities
  ADD CONSTRAINT partner_opportunities_selected_app_fkey
  FOREIGN KEY (selected_application_id) REFERENCES opportunity_applications(id) ON DELETE SET NULL;

ALTER TABLE lead_referrals
  DROP CONSTRAINT IF EXISTS lead_referrals_opportunity_fkey;
ALTER TABLE lead_referrals
  ADD CONSTRAINT lead_referrals_opportunity_fkey
  FOREIGN KEY (opportunity_id) REFERENCES partner_opportunities(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_partner_opportunities_board
  ON partner_opportunities(target_vertical, region, created_at DESC) WHERE status = 'open';
CREATE INDEX IF NOT EXISTS idx_partner_opportunities_tenant
  ON partner_opportunities(tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_opportunity_applications_opp
  ON opportunity_applications(opportunity_id);
CREATE INDEX IF NOT EXISTS idx_opportunity_applications_tenant
  ON opportunity_applications(applicant_tenant_id, created_at DESC);

ALTER TABLE partner_opportunities   ENABLE ROW LEVEL SECURITY;
ALTER TABLE opportunity_applications ENABLE ROW LEVEL SECURITY;
-- No policies on purpose: all access via SECURITY DEFINER RPCs below.

-- ── 3. publish_opportunity() ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.publish_opportunity(
  p_title text, p_description text, p_target_vertical text,
  p_region text, p_city text,
  p_commission_type text DEFAULT 'none', p_commission_value numeric DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_id        uuid;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;
  IF p_target_vertical NOT IN ('realestate','realestate_lawyer','interior') THEN
    RAISE EXCEPTION 'invalid vertical';
  END IF;
  IF p_region NOT IN ('north','haifa','sharon','center','telaviv','jerusalem','shfela','south') THEN
    RAISE EXCEPTION 'invalid_region';
  END IF;
  IF char_length(coalesce(trim(p_title),'')) < 5 THEN RAISE EXCEPTION 'title_too_short'; END IF;

  -- Rate limit: 5 opportunities per user per 24h
  IF (SELECT count(*) FROM partner_opportunities
      WHERE created_by = auth.uid() AND created_at > now() - interval '24 hours') >= 5 THEN
    RAISE EXCEPTION 'opportunity_rate_limit';
  END IF;

  INSERT INTO partner_opportunities (
    tenant_id, created_by, title, description, target_vertical, region, city,
    commission_type, commission_value
  ) VALUES (
    v_tenant_id, auth.uid(),
    left(trim(p_title), 120),
    nullif(left(coalesce(p_description,''), 1000), ''),
    p_target_vertical, p_region, nullif(left(coalesce(trim(p_city),''), 80), ''),
    coalesce(p_commission_type, 'none'),
    CASE WHEN coalesce(p_commission_type,'none') = 'none' THEN NULL ELSE p_commission_value END
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.publish_opportunity(text,text,text,text,text,text,numeric) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.publish_opportunity(text,text,text,text,text,text,numeric) FROM anon;
GRANT  EXECUTE ON FUNCTION public.publish_opportunity(text,text,text,text,text,text,numeric) TO authenticated;

-- ── 4. list_open_opportunities(): the anonymous board ─────────────────────

CREATE OR REPLACE FUNCTION public.list_open_opportunities(
  p_vertical text DEFAULT NULL, p_region text DEFAULT NULL
) RETURNS TABLE (
  id uuid, title text, description text, target_vertical text,
  publisher_vertical text, region text, city text,
  commission_type text, commission_value numeric,
  applications_count bigint, my_application_status text, created_at timestamptz
) LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;

  -- Lazy expiry sweep
  UPDATE partner_opportunities SET status = 'expired'
  WHERE status = 'open' AND expires_at < now();

  RETURN QUERY
  SELECT o.id, o.title, o.description, o.target_vertical,
         coalesce(t.industry, 'other'),
         o.region, o.city, o.commission_type, o.commission_value,
         (SELECT count(*) FROM opportunity_applications a
           WHERE a.opportunity_id = o.id AND a.status IN ('pending','selected')),
         (SELECT a.status FROM opportunity_applications a
           WHERE a.opportunity_id = o.id AND a.applicant_tenant_id = v_tenant_id),
         o.created_at
  FROM partner_opportunities o
  JOIN tenants t ON t.id = o.tenant_id
  WHERE o.status = 'open'
    AND o.tenant_id <> v_tenant_id            -- never my own; publisher stays anonymous
    AND (p_vertical IS NULL OR o.target_vertical = p_vertical)
    AND (p_region  IS NULL OR o.region = p_region)
  ORDER BY o.created_at DESC
  LIMIT 100;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_open_opportunities(text,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.list_open_opportunities(text,text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.list_open_opportunities(text,text) TO authenticated;

-- ── 5. list_my_opportunities() + close_opportunity() ──────────────────────

CREATE OR REPLACE FUNCTION public.list_my_opportunities()
RETURNS TABLE (
  id uuid, title text, description text, target_vertical text, region text, city text,
  commission_type text, commission_value numeric, status text,
  applications_count bigint, created_at timestamptz, expires_at timestamptz
) LANGUAGE sql SECURITY DEFINER SET search_path TO 'public' AS $fn$
  SELECT o.id, o.title, o.description, o.target_vertical, o.region, o.city,
         o.commission_type, o.commission_value, o.status,
         (SELECT count(*) FROM opportunity_applications a
           WHERE a.opportunity_id = o.id AND a.status IN ('pending','selected')),
         o.created_at, o.expires_at
  FROM partner_opportunities o
  WHERE o.tenant_id = get_my_tenant_id()
  ORDER BY o.created_at DESC
  LIMIT 50;
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_my_opportunities() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.list_my_opportunities() FROM anon;
GRANT  EXECUTE ON FUNCTION public.list_my_opportunities() TO authenticated;

CREATE OR REPLACE FUNCTION public.close_opportunity(p_opportunity_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;

  UPDATE partner_opportunities SET status = 'closed'
  WHERE id = p_opportunity_id AND tenant_id = v_tenant_id AND status = 'open';
  IF NOT FOUND THEN RAISE EXCEPTION 'opportunity_not_found'; END IF;

  RETURN jsonb_build_object('ok', true);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.close_opportunity(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.close_opportunity(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.close_opportunity(uuid) TO authenticated;

-- ── 6. apply_to_opportunity() + withdraw_my_application() ─────────────────

CREATE OR REPLACE FUNCTION public.apply_to_opportunity(p_opportunity_id uuid, p_message text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_opp       partner_opportunities%ROWTYPE;
  v_industry  text;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;

  -- Rate limit: 10 applications per user per 24h
  IF (SELECT count(*) FROM opportunity_applications
      WHERE applicant_user_id = auth.uid() AND created_at > now() - interval '24 hours') >= 10 THEN
    RAISE EXCEPTION 'application_rate_limit';
  END IF;

  SELECT * INTO v_opp FROM partner_opportunities WHERE id = p_opportunity_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'opportunity_not_found'; END IF;
  IF v_opp.tenant_id = v_tenant_id THEN RAISE EXCEPTION 'opportunity_own'; END IF;
  IF v_opp.status <> 'open' OR v_opp.expires_at < now() THEN
    RAISE EXCEPTION 'opportunity_closed';
  END IF;

  SELECT industry INTO v_industry FROM tenants WHERE id = v_tenant_id;
  IF coalesce(v_industry,'other') <> v_opp.target_vertical THEN
    RAISE EXCEPTION 'opportunity_vertical_mismatch';
  END IF;

  BEGIN
    INSERT INTO opportunity_applications (opportunity_id, applicant_tenant_id, applicant_user_id, message)
    VALUES (p_opportunity_id, v_tenant_id, auth.uid(), nullif(left(coalesce(p_message,''), 500), ''));
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'already_applied';
  END;

  RETURN jsonb_build_object('ok', true);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.apply_to_opportunity(uuid,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.apply_to_opportunity(uuid,text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.apply_to_opportunity(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.withdraw_my_application(p_opportunity_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;

  UPDATE opportunity_applications SET status = 'withdrawn'
  WHERE opportunity_id = p_opportunity_id
    AND applicant_tenant_id = v_tenant_id AND status = 'pending';
  IF NOT FOUND THEN RAISE EXCEPTION 'application_not_found'; END IF;

  RETURN jsonb_build_object('ok', true);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.withdraw_my_application(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.withdraw_my_application(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.withdraw_my_application(uuid) TO authenticated;

-- ── 7. list_opportunity_applications(): publisher-only, reveals applicants ─

CREATE OR REPLACE FUNCTION public.list_opportunity_applications(p_opportunity_id uuid)
RETURNS TABLE (
  id uuid, applicant_name text, applicant_industry text, applicant_city text,
  applicant_region text, applicant_phone text, message text, status text,
  created_at timestamptz
) LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;
  IF NOT EXISTS (SELECT 1 FROM partner_opportunities o
                 WHERE o.id = p_opportunity_id AND o.tenant_id = v_tenant_id) THEN
    RAISE EXCEPTION 'opportunity_not_found';
  END IF;

  RETURN QUERY
  SELECT a.id, t.name, coalesce(t.industry,'other'), t.city, t.region, t.phone,
         a.message, a.status, a.created_at
  FROM opportunity_applications a
  JOIN tenants t ON t.id = a.applicant_tenant_id
  WHERE a.opportunity_id = p_opportunity_id
  ORDER BY a.created_at ASC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_opportunity_applications(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.list_opportunity_applications(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.list_opportunity_applications(uuid) TO authenticated;

-- ── 8. select_opportunity_applicant(): the unification point ──────────────
-- Publisher picks a partner → a DIRECTED lead_referral is created (locked to
-- that partner's tenant) carrying the opportunity's commission terms, and it
-- continues through the standard pipeline: consent → agreement → lead.

CREATE OR REPLACE FUNCTION public.select_opportunity_applicant(
  p_application_id uuid, p_lead_id uuid, p_require_consent boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_app       opportunity_applications%ROWTYPE;
  v_opp       partner_opportunities%ROWTYPE;
  v_applicant tenants%ROWTYPE;
  v_result    jsonb;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;
  IF p_lead_id IS NULL THEN RAISE EXCEPTION 'lead_required'; END IF;

  SELECT * INTO v_app FROM opportunity_applications WHERE id = p_application_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'application_not_found'; END IF;
  IF v_app.status <> 'pending' THEN RAISE EXCEPTION 'application_not_pending'; END IF;

  SELECT * INTO v_opp FROM partner_opportunities
  WHERE id = v_app.opportunity_id AND tenant_id = v_tenant_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'opportunity_not_found'; END IF;
  IF v_opp.status <> 'open' THEN RAISE EXCEPTION 'opportunity_closed'; END IF;

  SELECT * INTO v_applicant FROM tenants WHERE id = v_app.applicant_tenant_id;

  -- The referral inherits the opportunity's commission terms and is locked
  -- to the selected partner's tenant.
  v_result := _create_lead_referral_core(
    v_tenant_id, auth.uid(), p_lead_id,
    v_opp.target_vertical,
    coalesce(v_applicant.name, 'שותף Liders'),
    coalesce(v_applicant.phone, ''),
    'הזדמנות מלוח ההפניות: ' || v_opp.title,
    v_opp.commission_type, v_opp.commission_value,
    coalesce(p_require_consent, false),
    v_app.applicant_tenant_id, v_opp.id
  );

  UPDATE opportunity_applications SET status = 'selected' WHERE id = v_app.id;
  UPDATE opportunity_applications SET status = 'rejected'
  WHERE opportunity_id = v_opp.id AND id <> v_app.id AND status = 'pending';
  UPDATE partner_opportunities
  SET status = 'matched', selected_application_id = v_app.id
  WHERE id = v_opp.id;

  RETURN v_result || jsonb_build_object(
    'applicant_name',  v_applicant.name,
    'applicant_phone', v_applicant.phone
  );
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.select_opportunity_applicant(uuid,uuid,boolean) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.select_opportunity_applicant(uuid,uuid,boolean) FROM anon;
GRANT  EXECUTE ON FUNCTION public.select_opportunity_applicant(uuid,uuid,boolean) TO authenticated;

-- ── 9. count_new_opportunities(): notification badge ──────────────────────
-- Open opportunities matching MY vertical (and my region, if set) created
-- after p_since (client keeps last-seen in localStorage).

CREATE OR REPLACE FUNCTION public.count_new_opportunities(p_since timestamptz)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_industry  text;
  v_region    text;
  v_count     integer;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;
  SELECT industry, region INTO v_industry, v_region FROM tenants WHERE id = v_tenant_id;

  SELECT count(*) INTO v_count
  FROM partner_opportunities o
  WHERE o.status = 'open'
    AND o.expires_at > now()
    AND o.tenant_id <> v_tenant_id
    AND o.target_vertical = coalesce(v_industry, 'other')
    AND (v_region IS NULL OR o.region = v_region)
    AND o.created_at > coalesce(p_since, now() - interval '7 days');

  RETURN v_count;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.count_new_opportunities(timestamptz) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.count_new_opportunities(timestamptz) FROM anon;
GRANT  EXECUTE ON FUNCTION public.count_new_opportunities(timestamptz) TO authenticated;
