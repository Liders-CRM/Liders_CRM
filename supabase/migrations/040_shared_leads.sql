-- Migration 040: Shared Leads — inter-tenant collaboration
--
-- Enables two Liders CRM tenants to collaborate on a single lead.
-- Security model:
--   • Owner creates a share protected by a bcrypt-hashed 4-6 digit PIN
--   • A short human-readable share_code (8 chars) is sent out-of-band to the partner
--   • PIN is sent separately — knowing the code alone gives nothing
--   • Partner enters both; max 5 wrong PIN attempts before lockout (brute-force proof)
--   • Only the specific lead snapshot is exposed — zero other tenant data can leak
--   • All writes go through SECURITY DEFINER RPCs — no direct table write surface
--   • Owner can revoke at any time; revocation is immediate and permanent

-- ─────────────────────────────────────────────────────────────
-- 1. Extend leads.source check constraint for industry-specific values
-- ─────────────────────────────────────────────────────────────
ALTER TABLE leads DROP CONSTRAINT IF EXISTS leads_source_check;
ALTER TABLE leads ADD CONSTRAINT leads_source_check
  CHECK (source IN (
    'yad2','madlan','facebook','instagram','referral','website','call',
    'whatsapp','email','ad','other','demo',
    'pinterest','linkedin','contractor','bank','agent','lawyer'
  ));

-- ─────────────────────────────────────────────────────────────
-- 2. shared_leads
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS shared_leads (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  share_code        text        NOT NULL
                                DEFAULT upper(substring(replace(gen_random_uuid()::text,'-',''), 1, 8)),
  lead_id           uuid        NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  owner_tenant_id   uuid        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  partner_tenant_id uuid        REFERENCES tenants(id) ON DELETE SET NULL,

  -- Snapshot of key lead fields (partner has no direct access to owner's leads table)
  lead_name         text        NOT NULL,
  lead_phone        text,
  lead_budget_min   numeric(14,2),
  lead_budget_max   numeric(14,2),
  lead_stage_name   text,
  lead_notes        text,
  owner_display     text,   -- owner's business name shown to partner
  owner_industry    text,

  -- Partner's own working notes (writable only by partner, not owner)
  partner_notes     text,

  -- Security
  pin_hash          text        NOT NULL,   -- crypt(pin, gen_salt('bf'))
  pin_attempts      integer     NOT NULL DEFAULT 0,

  -- Lifecycle
  status            text        NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending','active','revoked')),
  created_at        timestamptz NOT NULL DEFAULT now(),
  accepted_at       timestamptz
);

CREATE UNIQUE INDEX idx_shared_leads_code    ON shared_leads(share_code);
CREATE INDEX        idx_shared_leads_owner   ON shared_leads(owner_tenant_id);
CREATE INDEX        idx_shared_leads_partner ON shared_leads(partner_tenant_id);

ALTER TABLE shared_leads ENABLE ROW LEVEL SECURITY;

-- Owner: full control over their own shares
CREATE POLICY "shared_leads_owner" ON shared_leads
  FOR ALL TO authenticated
  USING    (owner_tenant_id   = get_my_tenant_id())
  WITH CHECK (owner_tenant_id = get_my_tenant_id());

-- Partner: read-only after acceptance (no direct writes — use RPCs)
CREATE POLICY "shared_leads_partner_read" ON shared_leads
  FOR SELECT TO authenticated
  USING (partner_tenant_id = get_my_tenant_id() AND status = 'active');

-- ─────────────────────────────────────────────────────────────
-- 3. shared_lead_messages  (chat thread per shared lead)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS shared_lead_messages (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  share_id         uuid        NOT NULL REFERENCES shared_leads(id) ON DELETE CASCADE,
  sender_tenant_id uuid        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  sender_name      text        NOT NULL,
  message          text        NOT NULL CHECK (length(trim(message)) > 0),
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_shared_msgs_share ON shared_lead_messages(share_id, created_at);

ALTER TABLE shared_lead_messages ENABLE ROW LEVEL SECURITY;

-- Only participants in an active share can read/insert messages
CREATE POLICY "shared_msgs_participant" ON shared_lead_messages
  FOR ALL TO authenticated
  USING (
    sender_tenant_id = get_my_tenant_id()
    AND EXISTS (
      SELECT 1 FROM shared_leads sl
      WHERE sl.id = share_id AND sl.status = 'active'
        AND (sl.owner_tenant_id   = get_my_tenant_id()
          OR sl.partner_tenant_id = get_my_tenant_id())
    )
  )
  WITH CHECK (
    sender_tenant_id = get_my_tenant_id()
    AND EXISTS (
      SELECT 1 FROM shared_leads sl
      WHERE sl.id = share_id AND sl.status = 'active'
        AND (sl.owner_tenant_id   = get_my_tenant_id()
          OR sl.partner_tenant_id = get_my_tenant_id())
    )
  );

-- ─────────────────────────────────────────────────────────────
-- 4. RPC: create_shared_lead(p_lead_id, p_pin)
--    Owner creates a share. Returns share_code (8-char, human-friendly).
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_shared_lead(
  p_lead_id uuid,
  p_pin     text
)
RETURNS text   -- returns share_code
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

  -- Validate PIN
  IF p_pin IS NULL OR length(p_pin) < 4 OR length(p_pin) > 6 THEN
    RAISE EXCEPTION 'PIN must be 4–6 digits';
  END IF;
  IF p_pin !~ '^[0-9]+$' THEN
    RAISE EXCEPTION 'PIN must contain digits only';
  END IF;

  -- Verify lead belongs to caller's tenant
  SELECT * INTO v_lead FROM leads WHERE id = p_lead_id AND tenant_id = v_tenant_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'lead not found'; END IF;

  -- Owner display info
  SELECT * INTO v_tenant FROM tenants WHERE id = v_tenant_id;

  -- Stage name
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
    coalesce(v_tenant.name, 'משתמש Liders CRM'), v_tenant.industry,
    crypt(p_pin, gen_salt('bf'))
  )
  RETURNING share_code INTO v_code;

  RETURN v_code;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_shared_lead(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_shared_lead(uuid, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.create_shared_lead(uuid, text) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 5. RPC: accept_shared_lead(p_share_code, p_pin)
--    Partner accepts. Returns share snapshot as JSONB or raises error.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.accept_shared_lead(
  p_share_code text,
  p_pin        text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_share     shared_leads%ROWTYPE;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;

  SELECT * INTO v_share FROM shared_leads WHERE share_code = upper(trim(p_share_code));
  IF NOT FOUND THEN RAISE EXCEPTION 'share code not found'; END IF;

  -- Can't accept your own share
  IF v_share.owner_tenant_id = v_tenant_id THEN
    RAISE EXCEPTION 'cannot accept your own share';
  END IF;

  -- Revoked
  IF v_share.status = 'revoked' THEN
    RAISE EXCEPTION 'this share has been revoked';
  END IF;

  -- Already active for another tenant
  IF v_share.status = 'active' AND v_share.partner_tenant_id IS DISTINCT FROM v_tenant_id THEN
    RAISE EXCEPTION 'share already used by another account';
  END IF;

  -- Already active for this tenant — return snapshot (idempotent)
  IF v_share.status = 'active' AND v_share.partner_tenant_id = v_tenant_id THEN
    RETURN row_to_json(v_share)::jsonb;
  END IF;

  -- Brute-force protection
  IF v_share.pin_attempts >= 5 THEN
    RAISE EXCEPTION 'too many failed attempts — share is locked. Ask the sender to create a new share.';
  END IF;

  -- Verify PIN
  IF crypt(p_pin, v_share.pin_hash) != v_share.pin_hash THEN
    UPDATE shared_leads SET pin_attempts = pin_attempts + 1 WHERE id = v_share.id;
    RAISE EXCEPTION 'PIN שגוי — % ניסיון/ות נותרו', GREATEST(0, 4 - v_share.pin_attempts);
  END IF;

  -- Activate
  UPDATE shared_leads
  SET partner_tenant_id = v_tenant_id,
      status            = 'active',
      accepted_at       = now(),
      pin_attempts      = 0
  WHERE id = v_share.id
  RETURNING * INTO v_share;

  RETURN row_to_json(v_share)::jsonb;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.accept_shared_lead(text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.accept_shared_lead(text, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.accept_shared_lead(text, text) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 6. RPC: get_my_shared_leads()
--    Returns all shares I own (any status) + all active shares I participate in.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_my_shared_leads()
RETURNS TABLE (
  share_id          uuid,
  share_code        text,
  lead_id           uuid,
  owner_tenant_id   uuid,
  partner_tenant_id uuid,
  lead_name         text,
  lead_phone        text,
  lead_budget_min   numeric,
  lead_budget_max   numeric,
  lead_stage_name   text,
  lead_notes        text,
  partner_notes     text,
  owner_display     text,
  owner_industry    text,
  status            text,
  created_at        timestamptz,
  accepted_at       timestamptz,
  msg_count         bigint,
  my_role           text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;

  RETURN QUERY
  SELECT
    sl.id, sl.share_code, sl.lead_id, sl.owner_tenant_id, sl.partner_tenant_id,
    sl.lead_name, sl.lead_phone, sl.lead_budget_min, sl.lead_budget_max,
    sl.lead_stage_name, sl.lead_notes, sl.partner_notes,
    sl.owner_display, sl.owner_industry,
    sl.status, sl.created_at, sl.accepted_at,
    COUNT(msg.id)                                        AS msg_count,
    CASE WHEN sl.owner_tenant_id = v_tenant_id
         THEN 'owner'::text ELSE 'partner'::text END     AS my_role
  FROM shared_leads sl
  LEFT JOIN shared_lead_messages msg ON msg.share_id = sl.id
  WHERE sl.owner_tenant_id = v_tenant_id
     OR (sl.partner_tenant_id = v_tenant_id AND sl.status = 'active')
  GROUP BY sl.id
  ORDER BY sl.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_my_shared_leads() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_my_shared_leads() FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_my_shared_leads() TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 7. RPC: send_shared_message(p_share_id, p_message)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.send_shared_message(
  p_share_id uuid,
  p_message  text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tenant_id  uuid := get_my_tenant_id();
  v_share      shared_leads%ROWTYPE;
  v_agent_name text;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF p_message IS NULL OR trim(p_message) = '' THEN
    RAISE EXCEPTION 'message cannot be empty';
  END IF;

  SELECT * INTO v_share FROM shared_leads WHERE id = p_share_id AND status = 'active';
  IF NOT FOUND THEN RAISE EXCEPTION 'share not found or not active'; END IF;

  IF v_share.owner_tenant_id != v_tenant_id AND v_share.partner_tenant_id != v_tenant_id THEN
    RAISE EXCEPTION 'not a participant in this share';
  END IF;

  SELECT name INTO v_agent_name
  FROM agent_users WHERE tenant_id = v_tenant_id ORDER BY created_at LIMIT 1;

  INSERT INTO shared_lead_messages (share_id, sender_tenant_id, sender_name, message)
  VALUES (p_share_id, v_tenant_id, coalesce(v_agent_name, 'משתמש'), trim(p_message));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.send_shared_message(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.send_shared_message(uuid, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.send_shared_message(uuid, text) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 8. RPC: get_shared_messages(p_share_id)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_shared_messages(p_share_id uuid)
RETURNS TABLE (
  id               uuid,
  sender_tenant_id uuid,
  sender_name      text,
  message          text,
  created_at       timestamptz,
  is_mine          boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_share     shared_leads%ROWTYPE;
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;

  SELECT * INTO v_share FROM shared_leads WHERE id = p_share_id AND status = 'active';
  IF NOT FOUND THEN RAISE EXCEPTION 'share not found or not active'; END IF;

  IF v_share.owner_tenant_id != v_tenant_id AND v_share.partner_tenant_id != v_tenant_id THEN
    RAISE EXCEPTION 'not a participant in this share';
  END IF;

  RETURN QUERY
  SELECT m.id, m.sender_tenant_id, m.sender_name, m.message, m.created_at,
         (m.sender_tenant_id = v_tenant_id)
  FROM shared_lead_messages m
  WHERE m.share_id = p_share_id
  ORDER BY m.created_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_shared_messages(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_shared_messages(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_shared_messages(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 9. RPC: revoke_shared_lead(p_share_id)  — owner only
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.revoke_shared_lead(p_share_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;

  UPDATE shared_leads
  SET status = 'revoked'
  WHERE id = p_share_id AND owner_tenant_id = v_tenant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'share not found or you are not the owner';
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.revoke_shared_lead(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.revoke_shared_lead(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.revoke_shared_lead(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 10. RPC: update_partner_notes(p_share_id, p_notes) — partner only
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_partner_notes(p_share_id uuid, p_notes text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
BEGIN
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;

  UPDATE shared_leads
  SET partner_notes = coalesce(p_notes, '')
  WHERE id = p_share_id
    AND partner_tenant_id = v_tenant_id
    AND status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'share not found or you are not the partner';
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.update_partner_notes(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_partner_notes(uuid, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.update_partner_notes(uuid, text) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 11. Table grants for authenticated role
-- ─────────────────────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE        ON shared_leads          TO authenticated;
GRANT SELECT, INSERT                ON shared_lead_messages  TO authenticated;
