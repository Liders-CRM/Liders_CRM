-- Migration 061: Lead Referral Loop (לולאת הפניות) — MVP
--
-- Turns the natural referral network between the three verticals (realestate,
-- realestate_lawyer, interior) into an in-product action: a user refers a lead
-- to a colleague via a one-time WhatsApp link; the colleague (registered or
-- brand-new) accepts and the lead lands in their pipeline.
--
-- Security model (mirrors 040/046 conventions):
--   • anon/authenticated have ZERO table access — RPCs only (SECURITY DEFINER)
--   • lead_snapshot holds ONLY name / phone / area / context — never notes,
--     deal value or activity history
--   • token: 128-bit random hex, single-use, 14-day expiry
--   • create is rate-limited to 10/day per user
--   • preview (anon) exposes only: referrer business name, vertical, lead first name

CREATE TABLE IF NOT EXISTS lead_referrals (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  from_tenant_id        uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  from_user_id          uuid NOT NULL,
  lead_id               uuid REFERENCES leads(id) ON DELETE SET NULL,
  lead_snapshot         jsonb NOT NULL,
  to_vertical           text NOT NULL
                        CHECK (to_vertical IN ('realestate','realestate_lawyer','interior')),
  to_name               text,
  to_phone              text,
  token                 text UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(16), 'hex'),
  status                text NOT NULL DEFAULT 'sent'
                        CHECK (status IN ('sent','opened','accepted','converted','expired')),
  accepted_by_tenant_id uuid REFERENCES tenants(id) ON DELETE SET NULL,
  xp_credited           boolean NOT NULL DEFAULT false,
  created_at            timestamptz NOT NULL DEFAULT now(),
  expires_at            timestamptz NOT NULL DEFAULT now() + interval '14 days'
);

CREATE INDEX IF NOT EXISTS idx_lead_referrals_from    ON lead_referrals(from_tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_lead_referrals_pending ON lead_referrals(from_tenant_id) WHERE xp_credited = false;

ALTER TABLE lead_referrals ENABLE ROW LEVEL SECURITY;
-- No policies on purpose: all access via SECURITY DEFINER RPCs below.

-- ── create_lead_referral(): referrer creates a one-time referral link ──
CREATE OR REPLACE FUNCTION public.create_lead_referral(
  p_lead_id uuid, p_to_vertical text, p_to_name text, p_to_phone text, p_context text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_lead      leads%ROWTYPE;
  v_tenant    tenants%ROWTYPE;
  v_token     text;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;
  IF p_to_vertical NOT IN ('realestate','realestate_lawyer','interior') THEN
    RAISE EXCEPTION 'invalid vertical';
  END IF;

  -- Rate limit: 10 referrals per user per 24h
  IF (SELECT count(*) FROM lead_referrals
      WHERE from_user_id = auth.uid() AND created_at > now() - interval '24 hours') >= 10 THEN
    RAISE EXCEPTION 'referral_rate_limit';
  END IF;

  SELECT * INTO v_lead FROM leads WHERE id = p_lead_id AND tenant_id = v_tenant_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'lead not found'; END IF;
  SELECT * INTO v_tenant FROM tenants WHERE id = v_tenant_id;

  INSERT INTO lead_referrals (from_tenant_id, from_user_id, lead_id, lead_snapshot, to_vertical, to_name, to_phone)
  VALUES (
    v_tenant_id, auth.uid(), p_lead_id,
    jsonb_build_object(
      'name',              v_lead.name,
      'phone',             v_lead.phone,
      'area',              v_lead.desired_area,
      'context',           left(coalesce(p_context, ''), 300),
      'referrer_name',     coalesce(v_tenant.name, 'משתמש Liders CRM'),
      'referrer_industry', coalesce(v_tenant.industry, 'other')
    ),
    p_to_vertical, left(coalesce(p_to_name,''), 80), left(coalesce(p_to_phone,''), 30)
  )
  RETURNING token INTO v_token;

  RETURN v_token;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.create_lead_referral(uuid,text,text,text,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_lead_referral(uuid,text,text,text,text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.create_lead_referral(uuid,text,text,text,text) TO authenticated;

-- ── get_lead_referral_preview(): anon-safe limited preview for the inbound link ──
CREATE OR REPLACE FUNCTION public.get_lead_referral_preview(p_token text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_ref lead_referrals%ROWTYPE;
BEGIN
  SELECT * INTO v_ref FROM lead_referrals WHERE token = p_token;
  IF NOT FOUND THEN RETURN jsonb_build_object('found', false); END IF;

  IF v_ref.status IN ('sent','opened') AND v_ref.expires_at < now() THEN
    UPDATE lead_referrals SET status = 'expired' WHERE id = v_ref.id;
    RETURN jsonb_build_object('found', false);
  END IF;
  IF v_ref.status NOT IN ('sent','opened') THEN
    RETURN jsonb_build_object('found', false, 'status', v_ref.status);
  END IF;
  IF v_ref.status = 'sent' THEN
    UPDATE lead_referrals SET status = 'opened' WHERE id = v_ref.id;
  END IF;

  RETURN jsonb_build_object(
    'found',           true,
    'referrer_name',   v_ref.lead_snapshot->>'referrer_name',
    'to_vertical',     v_ref.to_vertical,
    'lead_first_name', split_part(coalesce(v_ref.lead_snapshot->>'name',''), ' ', 1)
  );
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.get_lead_referral_preview(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_lead_referral_preview(text) TO anon;
GRANT  EXECUTE ON FUNCTION public.get_lead_referral_preview(text) TO authenticated;

-- ── accept_lead_referral(): colleague accepts — lead is created in their pipeline ──
CREATE OR REPLACE FUNCTION public.accept_lead_referral(p_token text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_ref       lead_referrals%ROWTYPE;
  v_stage_id  uuid;
  v_source    text;
  v_notes     text;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;

  SELECT * INTO v_ref FROM lead_referrals WHERE token = p_token FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'referral_not_found'; END IF;
  IF v_ref.from_tenant_id = v_tenant_id THEN RAISE EXCEPTION 'referral_own'; END IF;
  IF v_ref.status NOT IN ('sent','opened') THEN RAISE EXCEPTION 'referral_used'; END IF;
  IF v_ref.expires_at < now() THEN
    UPDATE lead_referrals SET status = 'expired' WHERE id = v_ref.id;
    RAISE EXCEPTION 'referral_expired';
  END IF;

  SELECT id INTO v_stage_id FROM pipeline_stages
  WHERE tenant_id = v_tenant_id ORDER BY order_idx LIMIT 1;

  v_source := CASE WHEN v_ref.lead_snapshot->>'referrer_industry' = 'realestate'
                   THEN 'agent' ELSE 'referral' END;
  v_notes  := '🔗 התקבל בהפניה מ־' || coalesce(v_ref.lead_snapshot->>'referrer_name','קולגה')
              || CASE WHEN coalesce(v_ref.lead_snapshot->>'context','') <> ''
                      THEN E'\n"' || (v_ref.lead_snapshot->>'context') || '"' ELSE '' END;

  INSERT INTO leads (tenant_id, pipeline_stage_id, name, phone, source, desired_area, notes)
  VALUES (
    v_tenant_id, v_stage_id,
    coalesce(v_ref.lead_snapshot->>'name', 'ליד מהפניה'),
    coalesce(v_ref.lead_snapshot->>'phone', ''),
    v_source,
    v_ref.lead_snapshot->>'area',
    v_notes
  );

  UPDATE lead_referrals
  SET status = 'accepted', accepted_by_tenant_id = v_tenant_id
  WHERE id = v_ref.id;

  RETURN jsonb_build_object(
    'lead_name',     v_ref.lead_snapshot->>'name',
    'referrer_name', v_ref.lead_snapshot->>'referrer_name'
  );
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.accept_lead_referral(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.accept_lead_referral(text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.accept_lead_referral(text) TO authenticated;

-- ── pull_lead_referral_xp(): credits the referrer +250 XP per accepted referral (client-side XP) ──
CREATE OR REPLACE FUNCTION public.pull_lead_referral_xp()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_count     integer;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;
  WITH updated AS (
    UPDATE lead_referrals SET xp_credited = true
    WHERE from_tenant_id = v_tenant_id
      AND status IN ('accepted','converted')
      AND xp_credited = false
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM updated;
  RETURN v_count;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.pull_lead_referral_xp() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.pull_lead_referral_xp() FROM anon;
GRANT  EXECUTE ON FUNCTION public.pull_lead_referral_xp() TO authenticated;

-- ── list_my_lead_referrals(): referrer's stats for the referral screen ──
CREATE OR REPLACE FUNCTION public.list_my_lead_referrals()
RETURNS TABLE (
  id uuid, lead_name text, to_vertical text, to_name text,
  status text, created_at timestamptz
) LANGUAGE sql SECURITY DEFINER SET search_path TO 'public' AS $fn$
  SELECT r.id,
         r.lead_snapshot->>'name',
         r.to_vertical, r.to_name, r.status, r.created_at
  FROM lead_referrals r
  WHERE r.from_tenant_id = get_my_tenant_id()
  ORDER BY r.created_at DESC
  LIMIT 50;
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_my_lead_referrals() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.list_my_lead_referrals() FROM anon;
GRANT  EXECUTE ON FUNCTION public.list_my_lead_referrals() TO authenticated;
