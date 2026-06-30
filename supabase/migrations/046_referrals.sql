-- Migration 046: WhatsApp "friend brings friend" referral XP
--
-- Server-authoritative referral codes + cross-device claim tracking, so a
-- referrer can be credited 200 XP even though the referrer and the referred
-- friend are almost always on different browsers/devices (localStorage alone
-- cannot bridge that). Mirrors the project-wide convention: anon has zero
-- table access (see migration 020), every operation goes through a
-- SECURITY DEFINER RPC that derives the caller's own tenant via
-- get_my_tenant_id() / auth.uid() - never from a client-supplied tenant id.

ALTER TABLE tenants ADD COLUMN IF NOT EXISTS referral_code text;
CREATE UNIQUE INDEX IF NOT EXISTS tenants_referral_code_unique
  ON tenants (referral_code) WHERE referral_code IS NOT NULL;

CREATE TABLE IF NOT EXISTS referral_claims (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  referred_tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  xp_awarded         boolean NOT NULL DEFAULT false,
  created_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT referral_claims_referred_unique UNIQUE (referred_tenant_id),
  CONSTRAINT referral_claims_no_self_referral CHECK (referrer_tenant_id <> referred_tenant_id)
);

CREATE INDEX IF NOT EXISTS idx_referral_claims_referrer_pending
  ON referral_claims (referrer_tenant_id) WHERE xp_awarded = false;

ALTER TABLE referral_claims ENABLE ROW LEVEL SECURITY;
-- No policies for anon/authenticated - all access goes through the
-- SECURITY DEFINER RPCs below (anon has zero table access project-wide).

-- ── get_referral_code(): returns the caller's tenant referral code, generating one on first call ──
CREATE OR REPLACE FUNCTION public.get_referral_code()
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_code      text;
  v_attempt   int := 0;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;
  SELECT referral_code INTO v_code FROM tenants WHERE id = v_tenant_id;
  IF v_code IS NOT NULL THEN RETURN v_code; END IF;
  LOOP
    v_code := upper(substr(md5(v_tenant_id::text || clock_timestamp()::text || v_attempt::text), 1, 6));
    BEGIN
      UPDATE tenants SET referral_code = v_code WHERE id = v_tenant_id;
      RETURN v_code;
    EXCEPTION WHEN unique_violation THEN
      v_attempt := v_attempt + 1;
      IF v_attempt > 10 THEN RAISE EXCEPTION 'could not generate unique referral code'; END IF;
    END;
  END LOOP;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.get_referral_code() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_referral_code() FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_referral_code() TO authenticated;

-- ── claim_referral_signup(): called once by a newly-onboarded tenant with the inbound ?ref= code ──
CREATE OR REPLACE FUNCTION public.claim_referral_signup(p_code text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_my_tenant_id uuid := get_my_tenant_id();
  v_referrer_id  uuid;
BEGIN
  IF v_my_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;
  IF p_code IS NULL OR trim(p_code) = '' THEN RETURN; END IF;
  SELECT id INTO v_referrer_id FROM tenants WHERE referral_code = upper(trim(p_code));
  IF v_referrer_id IS NULL OR v_referrer_id = v_my_tenant_id THEN RETURN; END IF;
  INSERT INTO referral_claims (referrer_tenant_id, referred_tenant_id)
  VALUES (v_referrer_id, v_my_tenant_id)
  ON CONFLICT (referred_tenant_id) DO NOTHING;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.claim_referral_signup(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.claim_referral_signup(text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.claim_referral_signup(text) TO authenticated;

-- ── pull_pending_referral_xp(): returns count of newly-credited referrals (200 XP each, applied client-side) ──
CREATE OR REPLACE FUNCTION public.pull_pending_referral_xp()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_count     integer;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;
  WITH updated AS (
    UPDATE referral_claims SET xp_awarded = true
    WHERE referrer_tenant_id = v_tenant_id AND xp_awarded = false
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM updated;
  RETURN v_count;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.pull_pending_referral_xp() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.pull_pending_referral_xp() FROM anon;
GRANT  EXECUTE ON FUNCTION public.pull_pending_referral_xp() TO authenticated;
