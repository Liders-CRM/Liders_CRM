-- Liders CRM — Migration 013: Lock down register_demo_agent()
--
-- Two critical findings on this SECURITY DEFINER bootstrap function
-- (verified directly against the live DB — supabase-security.md flagged
-- "ensure register_demo_agent() is not callable by anon" as a check item;
-- it currently FAILS that check):
--
-- 1. anon (unauthenticated, public anon-key) can EXECUTE this function.
--    Anyone can POST /rest/v1/rpc/register_demo_agent with an arbitrary
--    p_email belonging to a real agent. Because auth.uid() is NULL for
--    anon, the ON CONFLICT (tenant_id, email) DO UPDATE branch overwrites
--    that agent's auth_user_id with NULL — silently breaking their
--    tenant binding (denial of service against a named individual).
--
-- 2. Even for authenticated callers, the function trusted the
--    client-supplied p_email rather than the caller's own verified JWT
--    email. Any signed-up user could call
--    register_demo_agent('Attacker', 'victim@example.com') and the
--    ON CONFLICT ... DO UPDATE SET auth_user_id = auth.uid() would REBIND
--    the victim's agent_users row to the attacker's auth identity —
--    full identity takeover within the demo tenant (attacker assumes the
--    victim's agent_id/role; victim is locked out; audit_log entries from
--    that point on are misattributed).
--
-- Fix: derive the email from auth.email() (the verified email on the
-- caller's own JWT) instead of trusting p_email, and restrict EXECUTE to
-- `authenticated` only. p_email stays in the signature (client still
-- passes it) but is now ignored server-side — purely defense in depth,
-- since a unique constraint on auth.users.email means a verified email
-- can only ever belong to one auth_user_id, making the ON CONFLICT
-- rebind safe once email is server-verified.

CREATE OR REPLACE FUNCTION public.register_demo_agent(p_name text, p_email text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_agent_id uuid;
  v_email    text := auth.email();
BEGIN
  IF auth.uid() IS NULL OR v_email IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  INSERT INTO agent_users (tenant_id, auth_user_id, name, email, role)
  VALUES ('00000000-0000-0000-0000-000000000001', auth.uid(), p_name, v_email, 'agent')
  ON CONFLICT (tenant_id, email)
    DO UPDATE SET auth_user_id = auth.uid(), name = EXCLUDED.name, is_active = true
  RETURNING id INTO v_agent_id;

  RETURN v_agent_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.register_demo_agent(text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.register_demo_agent(text, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.register_demo_agent(text, text) TO authenticated;
