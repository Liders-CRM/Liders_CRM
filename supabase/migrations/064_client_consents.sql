-- Migration 064: Client Consents (הסכמת לקוח דיגיטלית להעברת פרטים)
--
-- Privacy/anti-spam gate: before a lead is transferred to a partner, the
-- client themselves can be asked to approve the transfer. The referrer's
-- WhatsApp opens with a ready message to the CLIENT containing a secure
-- one-time link (https://liders-crm.com/?consent={token}); the client taps
-- approve/decline on a dedicated page (no login). Approval releases the
-- referral (awaiting_consent → sent); decline blocks it (consent_declined).
--
-- Evidence stored: exact consent wording, response time, IP, user-agent.
--
-- Also recreates create_lead_referral with the full pipeline parameters
-- (commission from 063 + consent) and list_my_lead_referrals with both
-- directions (sent + received).

-- ── 1. client_consents ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS client_consents (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id         uuid NOT NULL UNIQUE REFERENCES lead_referrals(id) ON DELETE CASCADE,
  tenant_id           uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  requested_by        uuid NOT NULL,
  lead_id             uuid REFERENCES leads(id) ON DELETE SET NULL,
  client_name         text,
  client_phone        text,
  consent_text        text NOT NULL,          -- exact wording shown to the client
  token               text UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(16), 'hex'),
  status              text NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending','approved','declined','expired','cancelled')),
  responded_at        timestamptz,
  response_ip         text,
  response_user_agent text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  expires_at          timestamptz NOT NULL DEFAULT now() + interval '7 days'
);

CREATE INDEX IF NOT EXISTS idx_client_consents_tenant ON client_consents(tenant_id, created_at DESC);

ALTER TABLE client_consents ENABLE ROW LEVEL SECURITY;
-- No policies on purpose: all access via SECURITY DEFINER RPCs below.

-- ── 2. Core creator (internal, reused by the opportunity board in 065) ────

CREATE OR REPLACE FUNCTION public._create_lead_referral_core(
  p_tenant_id uuid, p_user_id uuid, p_lead_id uuid,
  p_to_vertical text, p_to_name text, p_to_phone text, p_context text,
  p_commission_type text, p_commission_value numeric, p_require_consent boolean,
  p_to_tenant_id uuid, p_opportunity_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_lead          leads%ROWTYPE;
  v_tenant        tenants%ROWTYPE;
  v_referral_id   uuid;
  v_token         text;
  v_consent_token text;
  v_consent_text  text;
BEGIN
  IF p_to_vertical NOT IN ('realestate','realestate_lawyer','interior') THEN
    RAISE EXCEPTION 'invalid vertical';
  END IF;
  IF p_commission_type NOT IN ('none','percent','fixed') THEN
    RAISE EXCEPTION 'invalid_commission_type';
  END IF;
  IF p_commission_type = 'none' AND p_commission_value IS NOT NULL THEN
    RAISE EXCEPTION 'invalid_commission_value';
  END IF;
  IF p_commission_type = 'percent' AND (p_commission_value IS NULL OR p_commission_value <= 0 OR p_commission_value > 50) THEN
    RAISE EXCEPTION 'invalid_commission_value';
  END IF;
  IF p_commission_type = 'fixed' AND (p_commission_value IS NULL OR p_commission_value <= 0 OR p_commission_value > 1000000) THEN
    RAISE EXCEPTION 'invalid_commission_value';
  END IF;

  SELECT * INTO v_lead FROM leads WHERE id = p_lead_id AND tenant_id = p_tenant_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'lead not found'; END IF;
  SELECT * INTO v_tenant FROM tenants WHERE id = p_tenant_id;

  INSERT INTO lead_referrals (
    from_tenant_id, from_user_id, lead_id, lead_snapshot, to_vertical, to_name, to_phone,
    commission_type, commission_value, to_tenant_id, opportunity_id, status
  )
  VALUES (
    p_tenant_id, p_user_id, p_lead_id,
    jsonb_build_object(
      'name',              v_lead.name,
      'phone',             v_lead.phone,
      'area',              v_lead.desired_area,
      'context',           left(coalesce(p_context, ''), 300),
      'referrer_name',     coalesce(v_tenant.name, 'משתמש Liders CRM'),
      'referrer_industry', coalesce(v_tenant.industry, 'other')
    ),
    p_to_vertical, left(coalesce(p_to_name,''), 80), left(coalesce(p_to_phone,''), 30),
    p_commission_type,
    CASE WHEN p_commission_type = 'none' THEN NULL ELSE p_commission_value END,
    p_to_tenant_id, p_opportunity_id,
    CASE WHEN p_require_consent THEN 'awaiting_consent' ELSE 'sent' END
  )
  RETURNING id, token INTO v_referral_id, v_token;

  IF p_commission_type <> 'none' THEN
    INSERT INTO referral_agreements (
      referral_id, from_tenant_id, from_user_id,
      commission_type, commission_value, agreement_text
    ) VALUES (
      v_referral_id, p_tenant_id, p_user_id,
      p_commission_type, p_commission_value,
      _build_referral_agreement_text(
        coalesce(v_tenant.name, 'משתמש Liders CRM'), p_to_vertical,
        split_part(coalesce(v_lead.name,''), ' ', 1),
        p_commission_type, p_commission_value
      )
    );
  END IF;

  IF p_require_consent THEN
    v_consent_text := 'היי ' || split_part(coalesce(v_lead.name,''), ' ', 1) || ', '
      || coalesce(v_tenant.name, 'משתמש Liders CRM')
      || ' מבקש את אישורך להעביר את פרטיך (שם וטלפון בלבד) ל'
      || _vertical_label_he(p_to_vertical)
      || ' שותף, לצורך המשך טיפול מקצועי. הפרטים יועברו רק אם תאשר.';

    INSERT INTO client_consents (
      referral_id, tenant_id, requested_by, lead_id, client_name, client_phone, consent_text
    ) VALUES (
      v_referral_id, p_tenant_id, p_user_id, p_lead_id,
      v_lead.name, v_lead.phone, v_consent_text
    )
    RETURNING token INTO v_consent_token;
  END IF;

  RETURN jsonb_build_object(
    'referral_id',   v_referral_id,
    'token',         v_token,
    'consent_token', v_consent_token,
    'client_phone',  v_lead.phone,
    'client_name',   v_lead.name
  );
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public._create_lead_referral_core(uuid,uuid,uuid,text,text,text,text,text,numeric,boolean,uuid,uuid) FROM PUBLIC, anon, authenticated;

-- ── 3. create_lead_referral(): full pipeline version ──────────────────────
-- Return type changed (text → jsonb) so the old function must be dropped.

DROP FUNCTION IF EXISTS public.create_lead_referral(uuid,text,text,text,text);

CREATE OR REPLACE FUNCTION public.create_lead_referral(
  p_lead_id uuid, p_to_vertical text, p_to_name text, p_to_phone text, p_context text,
  p_commission_type text DEFAULT 'none',
  p_commission_value numeric DEFAULT NULL,
  p_require_consent boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;

  -- Rate limit: 10 referrals per user per 24h
  IF (SELECT count(*) FROM lead_referrals
      WHERE from_user_id = auth.uid() AND created_at > now() - interval '24 hours') >= 10 THEN
    RAISE EXCEPTION 'referral_rate_limit';
  END IF;

  RETURN _create_lead_referral_core(
    v_tenant_id, auth.uid(), p_lead_id,
    p_to_vertical, p_to_name, p_to_phone, p_context,
    coalesce(p_commission_type, 'none'), p_commission_value, coalesce(p_require_consent, false),
    NULL, NULL
  );
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.create_lead_referral(uuid,text,text,text,text,text,numeric,boolean) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_lead_referral(uuid,text,text,text,text,text,numeric,boolean) FROM anon;
GRANT  EXECUTE ON FUNCTION public.create_lead_referral(uuid,text,text,text,text,text,numeric,boolean) TO authenticated;

-- ── 4. get_client_consent_preview(): anon-safe page content ───────────────
-- Token space is 128-bit random hex (same anti-scan posture as 061 preview).

CREATE OR REPLACE FUNCTION public.get_client_consent_preview(p_token text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_con client_consents%ROWTYPE;
  v_ref lead_referrals%ROWTYPE;
BEGIN
  SELECT * INTO v_con FROM client_consents WHERE token = p_token;
  IF NOT FOUND THEN RETURN jsonb_build_object('found', false); END IF;

  IF v_con.status = 'pending' AND v_con.expires_at < now() THEN
    UPDATE client_consents SET status = 'expired' WHERE id = v_con.id;
    RETURN jsonb_build_object('found', false);
  END IF;
  IF v_con.status <> 'pending' THEN
    RETURN jsonb_build_object('found', false, 'status', v_con.status);
  END IF;

  SELECT * INTO v_ref FROM lead_referrals WHERE id = v_con.referral_id;

  RETURN jsonb_build_object(
    'found',             true,
    'business_name',     v_ref.lead_snapshot->>'referrer_name',
    'to_vertical_label', _vertical_label_he(v_ref.to_vertical),
    'client_first_name', split_part(coalesce(v_con.client_name,''), ' ', 1),
    'consent_text',      v_con.consent_text
  );
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.get_client_consent_preview(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_client_consent_preview(text) TO anon;
GRANT  EXECUTE ON FUNCTION public.get_client_consent_preview(text) TO authenticated;

-- ── 5. respond_client_consent(): the client's approve/decline (anon) ──────

CREATE OR REPLACE FUNCTION public.respond_client_consent(p_token text, p_approved boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_con     client_consents%ROWTYPE;
  v_headers jsonb;
BEGIN
  IF p_approved IS NULL THEN RAISE EXCEPTION 'invalid_response'; END IF;

  SELECT * INTO v_con FROM client_consents WHERE token = p_token FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'consent_not_found'; END IF;
  IF v_con.status <> 'pending' THEN RAISE EXCEPTION 'consent_used'; END IF;
  IF v_con.expires_at < now() THEN
    UPDATE client_consents SET status = 'expired' WHERE id = v_con.id;
    RAISE EXCEPTION 'consent_expired';
  END IF;

  v_headers := coalesce(nullif(current_setting('request.headers', true), '')::jsonb, '{}'::jsonb);

  UPDATE client_consents SET
    status              = CASE WHEN p_approved THEN 'approved' ELSE 'declined' END,
    responded_at        = now(),
    response_ip         = left(coalesce(v_headers->>'x-forwarded-for',''), 100),
    response_user_agent = left(coalesce(v_headers->>'user-agent',''), 300)
  WHERE id = v_con.id;

  -- Release or block the referral
  UPDATE lead_referrals
  SET status = CASE WHEN p_approved THEN 'sent' ELSE 'consent_declined' END
  WHERE id = v_con.referral_id AND status = 'awaiting_consent';

  RETURN jsonb_build_object('ok', true, 'approved', p_approved);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.respond_client_consent(text,boolean) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.respond_client_consent(text,boolean) TO anon;
GRANT  EXECUTE ON FUNCTION public.respond_client_consent(text,boolean) TO authenticated;

-- ── 6. cancel_client_consent(): referrer withdraws a pending request ──────

CREATE OR REPLACE FUNCTION public.cancel_client_consent(p_referral_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;

  UPDATE client_consents SET status = 'cancelled'
  WHERE referral_id = p_referral_id AND tenant_id = v_tenant_id AND status = 'pending';
  IF NOT FOUND THEN RAISE EXCEPTION 'consent_not_found'; END IF;

  UPDATE lead_referrals SET status = 'cancelled'
  WHERE id = p_referral_id AND from_tenant_id = v_tenant_id AND status = 'awaiting_consent';

  RETURN jsonb_build_object('ok', true);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.cancel_client_consent(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cancel_client_consent(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.cancel_client_consent(uuid) TO authenticated;

-- ── 7. list_my_lead_referrals(): both directions + pipeline states ────────
-- Return shape changed — drop and recreate.

DROP FUNCTION IF EXISTS public.list_my_lead_referrals();

CREATE OR REPLACE FUNCTION public.list_my_lead_referrals()
RETURNS TABLE (
  id uuid, direction text, lead_name text, to_vertical text, to_name text,
  status text, commission_type text, commission_value numeric,
  consent_status text, agreement_status text,
  other_party text, token text, created_at timestamptz
) LANGUAGE sql SECURITY DEFINER SET search_path TO 'public' AS $fn$
  -- referrals I sent
  SELECT r.id, 'sent'::text,
         r.lead_snapshot->>'name',
         r.to_vertical, r.to_name, r.status,
         r.commission_type, r.commission_value,
         c.status, a.status,
         coalesce(t.name, r.to_name),
         r.token, r.created_at
  FROM lead_referrals r
  LEFT JOIN client_consents c      ON c.referral_id = r.id
  LEFT JOIN referral_agreements a  ON a.referral_id = r.id
  LEFT JOIN tenants t              ON t.id = r.accepted_by_tenant_id
  WHERE r.from_tenant_id = get_my_tenant_id()
  UNION ALL
  -- referrals directed to me (board) or accepted by me
  SELECT r.id, 'received'::text,
         CASE WHEN r.status IN ('accepted','converted')
              THEN r.lead_snapshot->>'name'
              ELSE split_part(coalesce(r.lead_snapshot->>'name',''), ' ', 1) END,
         r.to_vertical, r.to_name, r.status,
         r.commission_type, r.commission_value,
         c.status, a.status,
         r.lead_snapshot->>'referrer_name',
         CASE WHEN r.status IN ('sent','opened','awaiting_signature','awaiting_consent')
              THEN r.token ELSE NULL END,
         r.created_at
  FROM lead_referrals r
  LEFT JOIN client_consents c      ON c.referral_id = r.id
  LEFT JOIN referral_agreements a  ON a.referral_id = r.id
  WHERE r.from_tenant_id <> get_my_tenant_id()
    AND (r.accepted_by_tenant_id = get_my_tenant_id() OR r.to_tenant_id = get_my_tenant_id())
  ORDER BY created_at DESC
  LIMIT 50;
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_my_lead_referrals() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.list_my_lead_referrals() FROM anon;
GRANT  EXECUTE ON FUNCTION public.list_my_lead_referrals() TO authenticated;
