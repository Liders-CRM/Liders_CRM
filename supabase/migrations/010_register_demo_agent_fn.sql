-- Liders CRM — Migration 010: register_demo_agent() bootstrap function
--
-- Backfilled into the repo to match what is actually live (this file was
-- missing from supabase/migrations/ even though the function existed in
-- the database — verified via list_migrations against project
-- scyfywvzoogfrlalgftv, version 20260603165242).
--
-- ⚠️ This is the ORIGINAL definition as applied. It was found to grant
-- EXECUTE to `anon` (Postgres grants EXECUTE to PUBLIC by default on
-- CREATE FUNCTION unless explicitly revoked) and to trust a
-- client-supplied p_email for identity binding — both fixed by
-- migration 013_lock_down_register_demo_agent.sql. Kept here verbatim
-- for an accurate history of what shipped and when.

CREATE OR REPLACE FUNCTION public.register_demo_agent(p_name text, p_email text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_agent_id uuid;
BEGIN
  INSERT INTO agent_users (tenant_id, auth_user_id, name, email, role)
  VALUES ('00000000-0000-0000-0000-000000000001', auth.uid(), p_name, p_email, 'agent')
  ON CONFLICT (tenant_id, email)
    DO UPDATE SET auth_user_id = auth.uid(), name = EXCLUDED.name, is_active = true
  RETURNING id INTO v_agent_id;
  RETURN v_agent_id;
END;
$function$;
