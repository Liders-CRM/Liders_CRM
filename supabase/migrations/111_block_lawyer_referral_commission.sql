-- Block referral/opportunity commission whenever a lawyer (realestate_lawyer)
-- is on either side of the arrangement (referrer or target vertical).
--
-- Rationale (decided with the owner 23/7/2026, after a legal-risk pass ahead
-- of marketing to the realestate_lawyer vertical): the Israel Bar
-- Association's professional ethics rules restrict fee-sharing/referral
-- commissions between a lawyer and a non-lawyer. Rather than rely on every
-- lawyer-user to know and self-police this, the commission field is removed
-- entirely (server-side, not just hidden in the UI) whenever a lawyer is
-- involved. Plain, commission-free referrals to/from a lawyer remain fully
-- available — only the paid-commission arrangement is blocked.
--
-- This is enforced at the RPC layer (defense in depth over the UI hiding the
-- field), so a direct REST/RPC call cannot bypass it.

-- ── 1. _create_lead_referral_core: block commission when referrer or target
--       vertical is realestate_lawyer ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._create_lead_referral_core(
  p_tenant_id uuid, p_user_id uuid, p_lead_id uuid,
  p_to_vertical text, p_to_name text, p_to_phone text, p_context text,
  p_commission_type text, p_commission_value numeric, p_require_consent boolean,
  p_to_tenant_id uuid, p_opportunity_id uuid,
  p_external_profession text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_lead          leads%ROWTYPE;
  v_tenant        tenants%ROWTYPE;
  v_referral_id   uuid;
  v_token         text;
  v_consent_token text;
  v_consent_text  text;
BEGIN
  IF p_to_vertical NOT IN ('realestate','realestate_lawyer','interior','other') THEN
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

  IF p_commission_type <> 'none'
     AND (p_to_vertical = 'realestate_lawyer' OR coalesce(v_tenant.industry, 'other') = 'realestate_lawyer') THEN
    RAISE EXCEPTION 'commission_not_allowed_lawyer';
  END IF;

  INSERT INTO lead_referrals (
    from_tenant_id, from_user_id, lead_id, lead_snapshot,
    to_vertical, to_name, to_phone,
    commission_type, commission_value, to_tenant_id, opportunity_id, status,
    external_profession
  )
  VALUES (
    p_tenant_id, p_user_id, p_lead_id,
    jsonb_build_object(
      'name',              v_lead.name,
      'phone',             v_lead.phone,
      'area',              v_lead.desired_area,
      'context',           left(coalesce(p_context, ''), 300),
      'referrer_name',     coalesce(v_tenant.name, 'משתמש PLTO'),
      'referrer_industry', coalesce(v_tenant.industry, 'other')
    ),
    p_to_vertical,
    left(coalesce(p_to_name,''), 80),
    left(coalesce(p_to_phone,''), 30),
    p_commission_type,
    CASE WHEN p_commission_type = 'none' THEN NULL ELSE p_commission_value END,
    p_to_tenant_id, p_opportunity_id,
    CASE WHEN p_require_consent THEN 'awaiting_consent' ELSE 'sent' END,
    CASE WHEN p_to_vertical = 'other' THEN left(trim(coalesce(p_external_profession,'')), 80) ELSE NULL END
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
        coalesce(v_tenant.name, 'משתמש PLTO'), p_to_vertical,
        split_part(coalesce(v_lead.name,''), ' ', 1),
        p_commission_type, p_commission_value,
        p_external_profession
      )
    );
  END IF;

  IF p_require_consent THEN
    v_consent_text := 'היי ' || split_part(coalesce(v_lead.name,''), ' ', 1) || ', '
      || coalesce(v_tenant.name, 'משתמש PLTO')
      || ' מבקש את אישורך להעביר את פרטיך (שם וטלפון בלבד) ל'
      || coalesce(nullif(trim(p_external_profession),''), _vertical_label_he(p_to_vertical))
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

REVOKE EXECUTE ON FUNCTION public._create_lead_referral_core(uuid,uuid,uuid,text,text,text,text,text,numeric,boolean,uuid,uuid,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public._create_lead_referral_core(uuid,uuid,uuid,text,text,text,text,text,numeric,boolean,uuid,uuid,text) TO authenticated;

-- ── 2. publish_opportunity: block commission when target vertical or the
--       publisher's own industry is realestate_lawyer ─────────────────────
CREATE OR REPLACE FUNCTION public.publish_opportunity(
  p_title text, p_description text, p_target_vertical text,
  p_region text, p_city text,
  p_commission_type text DEFAULT 'none', p_commission_value numeric DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_id        uuid;
  v_industry  text;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;
  IF p_target_vertical NOT IN ('realestate','realestate_lawyer','interior') THEN
    RAISE EXCEPTION 'invalid vertical';
  END IF;
  IF p_region NOT IN ('north','haifa','sharon','center','telaviv','jerusalem','shfela','south') THEN
    RAISE EXCEPTION 'invalid_region';
  END IF;
  IF char_length(coalesce(trim(p_title),'')) < 5 THEN RAISE EXCEPTION 'title_too_short'; END IF;

  SELECT industry INTO v_industry FROM tenants WHERE id = v_tenant_id;
  IF coalesce(p_commission_type,'none') <> 'none'
     AND (p_target_vertical = 'realestate_lawyer' OR coalesce(v_industry, 'other') = 'realestate_lawyer') THEN
    RAISE EXCEPTION 'commission_not_allowed_lawyer';
  END IF;

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
