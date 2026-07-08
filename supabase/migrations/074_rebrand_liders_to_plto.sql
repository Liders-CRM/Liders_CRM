-- PLTO — Migration 074: Rebrand customer-visible strings from "Liders CRM" to "PLTO"
--
-- Recreates only the functions whose body contained the old brand name in
-- customer-visible text (agreement documents, WhatsApp messages, snapshots).
-- Admin-email whitelist strings (liders.crm@gmail.com) are NOT changed —
-- those are security controls, not branding.

-- ── 1. create_shared_lead ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_shared_lead(
  p_lead_id uuid,
  p_pin     text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tenant_id  uuid := get_my_tenant_id();
  v_lead       leads%ROWTYPE;
  v_tenant     tenants%ROWTYPE;
  v_stage_name text;
  v_code       text;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;

  IF p_pin IS NULL OR length(p_pin) < 4 OR length(p_pin) > 6 THEN
    RAISE EXCEPTION 'PIN must be 4–6 digits';
  END IF;
  IF p_pin !~ '^[0-9]+$' THEN
    RAISE EXCEPTION 'PIN must contain digits only';
  END IF;

  SELECT * INTO v_lead FROM leads WHERE id = p_lead_id AND tenant_id = v_tenant_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'lead not found'; END IF;

  SELECT * INTO v_tenant FROM tenants WHERE id = v_tenant_id;
  SELECT name INTO v_stage_name FROM pipeline_stages WHERE id = v_lead.pipeline_stage_id;

  INSERT INTO shared_leads (
    lead_id, owner_tenant_id,
    lead_name, lead_phone, lead_budget_min, lead_budget_max,
    lead_stage_name, lead_notes,
    owner_display, owner_industry,
    pin_hash
  ) VALUES (
    p_lead_id, v_tenant_id,
    v_lead.name, v_lead.phone, v_lead.budget_min, v_lead.budget_max,
    coalesce(v_stage_name, 'ליד'), v_lead.notes,
    coalesce(v_tenant.name, 'משתמש PLTO'), v_tenant.industry,
    crypt(p_pin, gen_salt('bf'))
  )
  RETURNING share_code INTO v_code;

  RETURN v_code;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_shared_lead(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_shared_lead(uuid, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.create_shared_lead(uuid, text) TO authenticated;

-- ── 2. _build_referral_agreement_text ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public._build_referral_agreement_text(
  p_referrer_name text, p_to_vertical text, p_lead_first_name text,
  p_commission_type text, p_commission_value numeric,
  p_to_profession text DEFAULT NULL
) RETURNS text LANGUAGE sql STABLE AS $fn$
  SELECT 'הסכם עמלת הפניה — PLTO' || E'\n'
      || '════════════════════════════' || E'\n\n'
      || 'המפנה: ' || p_referrer_name || E'\n'
      || 'המקבל: ' || coalesce(nullif(trim(p_to_profession),''), _vertical_label_he(p_to_vertical))
                   || ' (שמו המלא יופיע בחתימה)' || E'\n'
      || 'הליד המועבר: ' || coalesce(nullif(p_lead_first_name,''), 'ליד') || E'\n'
      || 'תאריך: ' || to_char(now() AT TIME ZONE 'Asia/Jerusalem', 'DD/MM/YYYY') || E'\n\n'
      || '1. המפנה מעביר למקבל ליד לטיפול מקצועי בתחומו של המקבל.' || E'\n'
      || '2. פרטי הליד המלאים ייחשפו למקבל רק לאחר חתימתו על הסכם זה.' || E'\n'
      || '3. אם תיסגר עסקה שמקורה בליד זה, ישלם המקבל למפנה עמלת הפניה בשיעור: '
      || _commission_label_he(p_commission_type, p_commission_value) || '.' || E'\n'
      || '4. התשלום יבוצע בתוך 30 יום ממועד קבלת התמורה בעסקה, כנגד חשבונית כדין.' || E'\n'
      || '5. המקבל מתחייב לטפל בליד במקצועיות ולעדכן את המפנה על סגירת עסקה שמקורה בהפניה.' || E'\n'
      || '6. הסכם זה תקף להפניה זו בלבד ואינו יוצר יחסי שותפות או שליחות בין הצדדים.' || E'\n'
      || '7. PLTO היא פלטפורמה טכנולוגית בלבד ואינה צד להסכם, אינה גובה את העמלה ואינה אחראית לאכיפתו.' || E'\n'
      || '8. החתימה הדיגיטלית שלהלן, בצירוף תיעוד מועד החתימה וזהות החותם, מהווה אישור הדדי מחייב בין הצדדים.' || E'\n';
$fn$;
REVOKE EXECUTE ON FUNCTION public._build_referral_agreement_text(text,text,text,text,numeric,text) FROM PUBLIC, anon, authenticated;

-- ── 3. _create_lead_referral_core ─────────────────────────────────────────
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

-- ── 4. select_opportunity_applicant ───────────────────────────────────────
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

  v_result := _create_lead_referral_core(
    v_tenant_id, auth.uid(), p_lead_id,
    v_opp.target_vertical,
    coalesce(v_applicant.name, 'שותף PLTO'),
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
