-- Migration 056: support_tickets — threaded conversations + human-escalation flag
-- Lets the AI carry on a real back-and-forth with the customer (up to ai-proxy's
-- MAX_MESSAGES cap) instead of one-shot Q&A, and flags when a human must step in.

ALTER TABLE support_tickets
  ADD COLUMN IF NOT EXISTS messages    jsonb   NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS needs_human boolean NOT NULL DEFAULT false;

-- Backfill any pre-existing single-shot tickets into thread format (safe no-op if empty)
UPDATE support_tickets
SET messages = COALESCE((
  SELECT jsonb_agg(m) FROM (
    SELECT jsonb_build_object('role','user','content',message,'ts',created_at) AS m
    UNION ALL
    SELECT jsonb_build_object('role','assistant','content',ai_response,'ts',created_at)
    WHERE ai_response IS NOT NULL
    UNION ALL
    SELECT jsonb_build_object('role','admin','content',admin_response,'ts',created_at)
    WHERE admin_response IS NOT NULL
  ) sub
), '[]'::jsonb)
WHERE messages = '[]'::jsonb;

-- Admin RPC: get all support tickets (now includes messages + needs_human)
DROP FUNCTION IF EXISTS public.get_support_tickets_admin();

CREATE FUNCTION public.get_support_tickets_admin()
RETURNS TABLE (
  id             uuid,
  tenant_id      uuid,
  tenant_name    text,
  agent_name     text,
  agent_email    text,
  message        text,
  ai_response    text,
  admin_response text,
  status         text,
  needs_human    boolean,
  messages       jsonb,
  created_at     timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_email text := auth.email();
BEGIN
  IF v_email NOT IN ('liders.crm@gmail.com','elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;
  RETURN QUERY
  SELECT s.id, s.tenant_id, s.tenant_name, s.agent_name, s.agent_email,
         s.message, s.ai_response, s.admin_response, s.status, s.needs_human, s.messages, s.created_at
  FROM support_tickets s
  ORDER BY s.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_support_tickets_admin() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_support_tickets_admin() FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_support_tickets_admin() TO authenticated;

-- Admin RPC: reply to ticket — now also appends into the thread and clears the escalation flag
CREATE OR REPLACE FUNCTION public.admin_reply_support(
  p_ticket_id    uuid,
  p_response     text,
  p_status       text DEFAULT 'admin_replied'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_email text := auth.email();
BEGIN
  IF v_email NOT IN ('liders.crm@gmail.com','elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;
  UPDATE support_tickets
  SET admin_response = p_response,
      status = p_status,
      needs_human = false,
      messages = messages || jsonb_build_object('role','admin','content',p_response,'ts',now())
  WHERE id = p_ticket_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_reply_support(uuid,text,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_reply_support(uuid,text,text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.admin_reply_support(uuid,text,text) TO authenticated;

-- Service-role-only RPC for the daily digest edge function. Restricted purely by GRANT
-- (only callable with the service_role key, which never leaves Supabase/edge-function land) —
-- no auth.email() check needed since anon/authenticated have no EXECUTE grant at all.
CREATE OR REPLACE FUNCTION public.get_support_digest(p_since timestamptz)
RETURNS TABLE (
  id            uuid,
  tenant_name   text,
  agent_name    text,
  status        text,
  needs_human   boolean,
  message       text,
  message_count int,
  created_at    timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT s.id, s.tenant_name, s.agent_name, s.status, s.needs_human, s.message,
         jsonb_array_length(s.messages), s.created_at
  FROM support_tickets s
  WHERE s.created_at >= p_since
  ORDER BY s.created_at DESC;
$$;

REVOKE EXECUTE ON FUNCTION public.get_support_digest(timestamptz) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.get_support_digest(timestamptz) TO service_role;
