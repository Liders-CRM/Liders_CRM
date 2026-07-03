-- Migration 063: Referral Commission Agreements (מנוע הסכמי עמלה וחתימה דיגיטלית)
--
-- Extends the referral loop (061) with an optional commission agreement:
-- a referral sent "with commission" is LOCKED — the receiving colleague sees
-- only a limited preview until they digitally sign a short referral agreement
-- (X% of the deal / fixed amount). Signing = accepting: one atomic action
-- creates the lead in the recipient's pipeline.
--
-- Security model (mirrors 061):
--   • anon/authenticated have ZERO table access — RPCs only (SECURITY DEFINER)
--   • agreement_text is a full server-built Hebrew snapshot of what was signed
--   • signature evidence: signer name, canvas drawing (data-URL ≤150KB),
--     sha256 integrity hash, signer IP + user-agent, timestamp
--   • commission: percent (≤50%) or fixed ILS amount

-- ── 1. Extend lead_referrals ──────────────────────────────────────────────

ALTER TABLE lead_referrals
  ADD COLUMN IF NOT EXISTS commission_type  text NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS commission_value numeric(10,2),
  ADD COLUMN IF NOT EXISTS to_tenant_id     uuid REFERENCES tenants(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS opportunity_id   uuid;  -- FK added in 065 (board)

ALTER TABLE lead_referrals DROP CONSTRAINT IF EXISTS lead_referrals_commission_check;
ALTER TABLE lead_referrals ADD CONSTRAINT lead_referrals_commission_check CHECK (
  (commission_type = 'none'    AND commission_value IS NULL) OR
  (commission_type = 'percent' AND commission_value > 0 AND commission_value <= 50) OR
  (commission_type = 'fixed'   AND commission_value > 0 AND commission_value <= 1000000)
);

-- New status machine:
--   awaiting_consent → sent → opened → [awaiting_signature →] accepted → converted
--   exits: consent_declined / declined / expired / cancelled
ALTER TABLE lead_referrals DROP CONSTRAINT IF EXISTS lead_referrals_status_check;
ALTER TABLE lead_referrals ADD CONSTRAINT lead_referrals_status_check CHECK (
  status IN ('awaiting_consent','consent_declined','sent','opened',
             'awaiting_signature','declined','accepted','converted','expired','cancelled')
);

-- ── 2. referral_agreements ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS referral_agreements (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id        uuid NOT NULL UNIQUE REFERENCES lead_referrals(id) ON DELETE CASCADE,
  from_tenant_id     uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  from_user_id       uuid NOT NULL,
  to_tenant_id       uuid REFERENCES tenants(id) ON DELETE SET NULL,  -- filled at signing
  to_user_id         uuid,
  commission_type    text NOT NULL CHECK (commission_type IN ('percent','fixed')),
  commission_value   numeric(10,2) NOT NULL CHECK (commission_value > 0),
  agreement_text     text NOT NULL,               -- exact Hebrew wording shown to signer
  agreement_version  text NOT NULL DEFAULT 'v1',
  status             text NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','signed','declined','expired','cancelled')),
  signer_name        text,
  signature_image    text CHECK (signature_image IS NULL OR length(signature_image) <= 150000),
  signature_hash     text,                        -- sha256(agreement_text‖signer‖signed_at‖token)
  signer_ip          text,
  signer_user_agent  text,
  declined_reason    text,
  signed_at          timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  expires_at         timestamptz NOT NULL DEFAULT now() + interval '14 days'
);

CREATE INDEX IF NOT EXISTS idx_referral_agreements_from ON referral_agreements(from_tenant_id, created_at DESC);

ALTER TABLE referral_agreements ENABLE ROW LEVEL SECURITY;
-- No policies on purpose: all access via SECURITY DEFINER RPCs below.

-- ── 3. Internal helpers (no grants — not callable from the API) ───────────

-- Hebrew label for a vertical
CREATE OR REPLACE FUNCTION public._vertical_label_he(p_vertical text)
RETURNS text LANGUAGE sql IMMUTABLE AS $fn$
  SELECT CASE p_vertical
    WHEN 'realestate'        THEN 'סוכן נדל"ן'
    WHEN 'realestate_lawyer' THEN 'עו"ד נדל"ן'
    WHEN 'interior'          THEN 'מעצב פנים'
    ELSE 'בעל מקצוע'
  END;
$fn$;
REVOKE EXECUTE ON FUNCTION public._vertical_label_he(text) FROM PUBLIC, anon, authenticated;

-- Human-readable commission phrase
CREATE OR REPLACE FUNCTION public._commission_label_he(p_type text, p_value numeric)
RETURNS text LANGUAGE sql IMMUTABLE AS $fn$
  SELECT CASE p_type
    WHEN 'percent' THEN trim(trailing '.' from trim(trailing '0' from p_value::text)) || '% מהתמורה בעסקה'
    WHEN 'fixed'   THEN '₪' || trim(trailing '.' from trim(trailing '0' from p_value::text)) || ' (סכום קבוע)'
    ELSE 'ללא עמלה'
  END;
$fn$;
REVOKE EXECUTE ON FUNCTION public._commission_label_he(text, numeric) FROM PUBLIC, anon, authenticated;

-- Server-built agreement wording (snapshot; the signed evidence)
CREATE OR REPLACE FUNCTION public._build_referral_agreement_text(
  p_referrer_name text, p_to_vertical text, p_lead_first_name text,
  p_commission_type text, p_commission_value numeric
) RETURNS text LANGUAGE sql STABLE AS $fn$
  SELECT 'הסכם עמלת הפניה — Liders CRM' || E'\n'
      || '════════════════════════════' || E'\n\n'
      || 'המפנה: ' || p_referrer_name || E'\n'
      || 'המקבל: ' || _vertical_label_he(p_to_vertical) || ' (שמו המלא יופיע בחתימה)' || E'\n'
      || 'הליד המועבר: ' || coalesce(nullif(p_lead_first_name,''), 'ליד') || E'\n'
      || 'תאריך: ' || to_char(now() AT TIME ZONE 'Asia/Jerusalem', 'DD/MM/YYYY') || E'\n\n'
      || '1. המפנה מעביר למקבל ליד לטיפול מקצועי בתחומו של המקבל.' || E'\n'
      || '2. פרטי הליד המלאים ייחשפו למקבל רק לאחר חתימתו על הסכם זה.' || E'\n'
      || '3. אם תיסגר עסקה שמקורה בליד זה, ישלם המקבל למפנה עמלת הפניה בשיעור: '
      || _commission_label_he(p_commission_type, p_commission_value) || '.' || E'\n'
      || '4. התשלום יבוצע בתוך 30 יום ממועד קבלת התמורה בעסקה, כנגד חשבונית כדין.' || E'\n'
      || '5. המקבל מתחייב לטפל בליד במקצועיות ולעדכן את המפנה על סגירת עסקה שמקורה בהפניה.' || E'\n'
      || '6. הסכם זה תקף להפניה זו בלבד ואינו יוצר יחסי שותפות או שליחות בין הצדדים.' || E'\n'
      || '7. Liders CRM היא פלטפורמה טכנולוגית בלבד ואינה צד להסכם, אינה גובה את העמלה ואינה אחראית לאכיפתו.' || E'\n'
      || '8. החתימה הדיגיטלית שלהלן, בצירוף תיעוד מועד החתימה וזהות החותם, מהווה אישור הדדי מחייב בין הצדדים.' || E'\n';
$fn$;
REVOKE EXECUTE ON FUNCTION public._build_referral_agreement_text(text,text,text,text,numeric) FROM PUBLIC, anon, authenticated;

-- Shared fulfilment: create the lead in the recipient's pipeline + mark accepted.
-- Called by accept_lead_referral (no commission) and sign_referral_agreement.
CREATE OR REPLACE FUNCTION public._fulfill_lead_referral(p_referral_id uuid, p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_ref      lead_referrals%ROWTYPE;
  v_stage_id uuid;
  v_source   text;
  v_notes    text;
  v_lead_id  uuid;
BEGIN
  SELECT * INTO v_ref FROM lead_referrals WHERE id = p_referral_id;

  SELECT id INTO v_stage_id FROM pipeline_stages
  WHERE tenant_id = p_tenant_id ORDER BY order_idx LIMIT 1;

  v_source := CASE WHEN v_ref.lead_snapshot->>'referrer_industry' = 'realestate'
                   THEN 'agent' ELSE 'referral' END;
  v_notes  := '🔗 התקבל בהפניה מ־' || coalesce(v_ref.lead_snapshot->>'referrer_name','קולגה')
              || CASE WHEN coalesce(v_ref.lead_snapshot->>'context','') <> ''
                      THEN E'\n"' || (v_ref.lead_snapshot->>'context') || '"' ELSE '' END;

  INSERT INTO leads (tenant_id, pipeline_stage_id, name, phone, source, desired_area, notes)
  VALUES (
    p_tenant_id, v_stage_id,
    coalesce(v_ref.lead_snapshot->>'name', 'ליד מהפניה'),
    coalesce(v_ref.lead_snapshot->>'phone', ''),
    v_source,
    v_ref.lead_snapshot->>'area',
    v_notes
  )
  RETURNING id INTO v_lead_id;

  UPDATE lead_referrals
  SET status = 'accepted', accepted_by_tenant_id = p_tenant_id
  WHERE id = v_ref.id;

  RETURN jsonb_build_object(
    'lead_id',       v_lead_id,
    'lead_name',     v_ref.lead_snapshot->>'name',
    'referrer_name', v_ref.lead_snapshot->>'referrer_name'
  );
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public._fulfill_lead_referral(uuid, uuid) FROM PUBLIC, anon, authenticated;

-- ── 4. get_lead_referral_preview(): now reports lock + commission terms ───

CREATE OR REPLACE FUNCTION public.get_lead_referral_preview(p_token text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_ref lead_referrals%ROWTYPE;
BEGIN
  SELECT * INTO v_ref FROM lead_referrals WHERE token = p_token;
  IF NOT FOUND THEN RETURN jsonb_build_object('found', false); END IF;

  IF v_ref.status IN ('sent','opened','awaiting_signature') AND v_ref.expires_at < now() THEN
    UPDATE lead_referrals SET status = 'expired' WHERE id = v_ref.id;
    RETURN jsonb_build_object('found', false);
  END IF;
  IF v_ref.status NOT IN ('sent','opened','awaiting_signature') THEN
    RETURN jsonb_build_object('found', false, 'status', v_ref.status);
  END IF;
  IF v_ref.status = 'sent' THEN
    UPDATE lead_referrals SET status = 'opened' WHERE id = v_ref.id;
  END IF;

  RETURN jsonb_build_object(
    'found',            true,
    'referrer_name',    v_ref.lead_snapshot->>'referrer_name',
    'to_vertical',      v_ref.to_vertical,
    'lead_first_name',  split_part(coalesce(v_ref.lead_snapshot->>'name',''), ' ', 1),
    'locked',           v_ref.commission_type <> 'none',
    'commission_type',  v_ref.commission_type,
    'commission_value', v_ref.commission_value,
    'commission_label', CASE WHEN v_ref.commission_type <> 'none'
                             THEN _commission_label_he(v_ref.commission_type, v_ref.commission_value)
                             ELSE NULL END
  );
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.get_lead_referral_preview(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_lead_referral_preview(text) TO anon;
GRANT  EXECUTE ON FUNCTION public.get_lead_referral_preview(text) TO authenticated;

-- ── 5. accept_lead_referral(): blocks commission referrals until signed ───

CREATE OR REPLACE FUNCTION public.accept_lead_referral(p_token text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_ref       lead_referrals%ROWTYPE;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;

  SELECT * INTO v_ref FROM lead_referrals WHERE token = p_token FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'referral_not_found'; END IF;
  IF v_ref.from_tenant_id = v_tenant_id THEN RAISE EXCEPTION 'referral_own'; END IF;
  IF v_ref.status = 'awaiting_consent' THEN RAISE EXCEPTION 'referral_pending_consent'; END IF;
  IF v_ref.status NOT IN ('sent','opened','awaiting_signature') THEN RAISE EXCEPTION 'referral_used'; END IF;
  IF v_ref.expires_at < now() THEN
    UPDATE lead_referrals SET status = 'expired' WHERE id = v_ref.id;
    RAISE EXCEPTION 'referral_expired';
  END IF;
  IF v_ref.to_tenant_id IS NOT NULL AND v_ref.to_tenant_id <> v_tenant_id THEN
    RAISE EXCEPTION 'referral_wrong_tenant';
  END IF;
  -- Commission referrals are LOCKED: signature required, plain accept refused.
  IF v_ref.commission_type <> 'none' THEN RAISE EXCEPTION 'agreement_required'; END IF;

  RETURN _fulfill_lead_referral(v_ref.id, v_tenant_id);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.accept_lead_referral(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.accept_lead_referral(text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.accept_lead_referral(text) TO authenticated;

-- ── 6. get_referral_agreement(): full wording for the signing screen ──────

CREATE OR REPLACE FUNCTION public.get_referral_agreement(p_token text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_ref       lead_referrals%ROWTYPE;
  v_agr       referral_agreements%ROWTYPE;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;

  SELECT * INTO v_ref FROM lead_referrals WHERE token = p_token;
  IF NOT FOUND THEN RAISE EXCEPTION 'referral_not_found'; END IF;
  IF v_ref.from_tenant_id = v_tenant_id THEN RAISE EXCEPTION 'referral_own'; END IF;
  IF v_ref.status = 'awaiting_consent' THEN RAISE EXCEPTION 'referral_pending_consent'; END IF;
  IF v_ref.status NOT IN ('sent','opened','awaiting_signature') THEN RAISE EXCEPTION 'referral_used'; END IF;
  IF v_ref.expires_at < now() THEN
    UPDATE lead_referrals SET status = 'expired' WHERE id = v_ref.id;
    RAISE EXCEPTION 'referral_expired';
  END IF;
  IF v_ref.to_tenant_id IS NOT NULL AND v_ref.to_tenant_id <> v_tenant_id THEN
    RAISE EXCEPTION 'referral_wrong_tenant';
  END IF;
  IF v_ref.commission_type = 'none' THEN RAISE EXCEPTION 'no_agreement_needed'; END IF;

  SELECT * INTO v_agr FROM referral_agreements WHERE referral_id = v_ref.id;
  IF NOT FOUND THEN RAISE EXCEPTION 'agreement_not_found'; END IF;

  -- Referrer sees "השותף צופה בהסכם" in the referrals screen
  IF v_ref.status IN ('sent','opened') THEN
    UPDATE lead_referrals SET status = 'awaiting_signature' WHERE id = v_ref.id;
  END IF;

  RETURN jsonb_build_object(
    'agreement_text',   v_agr.agreement_text,
    'commission_label', _commission_label_he(v_agr.commission_type, v_agr.commission_value),
    'referrer_name',    v_ref.lead_snapshot->>'referrer_name',
    'lead_first_name',  split_part(coalesce(v_ref.lead_snapshot->>'name',''), ' ', 1)
  );
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.get_referral_agreement(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_referral_agreement(text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_referral_agreement(text) TO authenticated;

-- ── 7. sign_referral_agreement(): signature = acceptance, one atomic step ─

CREATE OR REPLACE FUNCTION public.sign_referral_agreement(
  p_token text, p_signer_name text, p_signature_image text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_ref       lead_referrals%ROWTYPE;
  v_agr       referral_agreements%ROWTYPE;
  v_headers   jsonb;
  v_signed_at timestamptz := now();
  v_result    jsonb;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;
  IF coalesce(trim(p_signer_name), '') = '' THEN RAISE EXCEPTION 'signer_name_required'; END IF;
  IF p_signature_image IS NULL OR p_signature_image NOT LIKE 'data:image/%' THEN
    RAISE EXCEPTION 'signature_required';
  END IF;
  IF length(p_signature_image) > 150000 THEN RAISE EXCEPTION 'signature_too_large'; END IF;

  SELECT * INTO v_ref FROM lead_referrals WHERE token = p_token FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'referral_not_found'; END IF;
  IF v_ref.from_tenant_id = v_tenant_id THEN RAISE EXCEPTION 'referral_own'; END IF;
  IF v_ref.status = 'awaiting_consent' THEN RAISE EXCEPTION 'referral_pending_consent'; END IF;
  IF v_ref.status NOT IN ('sent','opened','awaiting_signature') THEN RAISE EXCEPTION 'referral_used'; END IF;
  IF v_ref.expires_at < now() THEN
    UPDATE lead_referrals SET status = 'expired' WHERE id = v_ref.id;
    RAISE EXCEPTION 'referral_expired';
  END IF;
  IF v_ref.to_tenant_id IS NOT NULL AND v_ref.to_tenant_id <> v_tenant_id THEN
    RAISE EXCEPTION 'referral_wrong_tenant';
  END IF;
  IF v_ref.commission_type = 'none' THEN RAISE EXCEPTION 'no_agreement_needed'; END IF;

  SELECT * INTO v_agr FROM referral_agreements WHERE referral_id = v_ref.id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'agreement_not_found'; END IF;
  IF v_agr.status <> 'pending' THEN RAISE EXCEPTION 'agreement_not_pending'; END IF;

  v_headers := coalesce(nullif(current_setting('request.headers', true), '')::jsonb, '{}'::jsonb);

  UPDATE referral_agreements SET
    status            = 'signed',
    to_tenant_id      = v_tenant_id,
    to_user_id        = auth.uid(),
    signer_name       = left(trim(p_signer_name), 120),
    signature_image   = p_signature_image,
    signature_hash    = encode(sha256(convert_to(
                          v_agr.agreement_text || '|' || trim(p_signer_name) || '|' ||
                          v_signed_at::text   || '|' || v_ref.token, 'UTF8')), 'hex'),
    signer_ip         = left(coalesce(v_headers->>'x-forwarded-for',''), 100),
    signer_user_agent = left(coalesce(v_headers->>'user-agent',''), 300),
    signed_at         = v_signed_at
  WHERE id = v_agr.id;

  v_result := _fulfill_lead_referral(v_ref.id, v_tenant_id);
  RETURN v_result || jsonb_build_object(
    'agreement_id',     v_agr.id,
    'commission_label', _commission_label_he(v_agr.commission_type, v_agr.commission_value)
  );
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.sign_referral_agreement(text,text,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.sign_referral_agreement(text,text,text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.sign_referral_agreement(text,text,text) TO authenticated;

-- ── 8. decline_referral_agreement() ───────────────────────────────────────

CREATE OR REPLACE FUNCTION public.decline_referral_agreement(p_token text, p_reason text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_ref       lead_referrals%ROWTYPE;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;

  SELECT * INTO v_ref FROM lead_referrals WHERE token = p_token FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'referral_not_found'; END IF;
  IF v_ref.from_tenant_id = v_tenant_id THEN RAISE EXCEPTION 'referral_own'; END IF;
  IF v_ref.status NOT IN ('sent','opened','awaiting_signature') THEN RAISE EXCEPTION 'referral_used'; END IF;
  IF v_ref.commission_type = 'none' THEN RAISE EXCEPTION 'no_agreement_needed'; END IF;

  UPDATE referral_agreements
  SET status = 'declined', declined_reason = left(coalesce(p_reason,''), 300),
      to_tenant_id = v_tenant_id, to_user_id = auth.uid()
  WHERE referral_id = v_ref.id AND status = 'pending';

  UPDATE lead_referrals SET status = 'declined' WHERE id = v_ref.id;

  RETURN jsonb_build_object('ok', true);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.decline_referral_agreement(text,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.decline_referral_agreement(text,text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.decline_referral_agreement(text,text) TO authenticated;
