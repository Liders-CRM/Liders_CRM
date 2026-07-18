-- Migration 098 (retroactive): update_tenant_integrations() drift fix
--
-- Discovered while investigating the WhatsApp self-notification bug (18/7/2026):
-- 028_fix_update_tenant_integrations_rpc.sql defines this function with
-- `WHERE id = auth.uid()`, comparing agent_users' own primary key against
-- the auth user id - these are different uuids (agent_users.auth_user_id
-- is the FK to auth.users, agent_users.id is its own generated PK), so that
-- lookup would never match and the RPC would always raise "No tenant found
-- for this user".
--
-- The live database has already been running a corrected version using
-- `WHERE auth_user_id = auth.uid()` (verified via pg_get_functiondef; the
-- Twilio number save in the screenshot that started this investigation did
-- reach tenants.whatsapp_number correctly). This migration only replays
-- that already-live, correct definition into the migration history so a
-- replay from a clean database doesn't reintroduce the broken version from
-- 028. No behavior changes on the live database.

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
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;

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

GRANT EXECUTE ON FUNCTION update_tenant_integrations(text, text) TO authenticated;
