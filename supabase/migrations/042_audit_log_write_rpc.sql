-- Migration 042: Audit log write access via SECURITY DEFINER RPC
-- Allows authenticated users to append audit events without exposing the
-- raw audit_log table (prevents fake-record injection).
-- Adds a SELECT policy so each tenant can view their own history.

-- Tenant admins can read their own audit log (e.g. admin panel)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename='audit_log' AND schemaname='public' AND policyname='tenant own audit read'
  ) THEN
    CREATE POLICY "tenant own audit read" ON public.audit_log
      FOR SELECT TO authenticated
      USING (tenant_id = get_my_tenant_id());
  END IF;
END $$;

-- SECURITY DEFINER RPC: safe insert with action whitelist
-- Called fire-and-forget from the client — never blocks the UI.
CREATE OR REPLACE FUNCTION public.append_audit(
  p_action      text,
  p_entity_type text  DEFAULT NULL,
  p_entity_id   uuid  DEFAULT NULL,
  p_details     jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_agent_id  uuid := get_my_agent_id();
BEGIN
  -- Whitelist: only these actions are allowed through from the client
  IF p_action NOT IN (
    'lead.created', 'lead.updated', 'lead.deleted', 'lead.stage_changed',
    'settings.updated', 'auth.login', 'property.created', 'property.deleted',
    'task.created', 'task.completed', 'security.injection_blocked'
  ) THEN
    RETURN; -- silently drop unknown actions
  END IF;

  INSERT INTO public.audit_log (tenant_id, agent_id, action, entity_type, entity_id, new_value)
  VALUES (v_tenant_id, v_agent_id, p_action, p_entity_type, p_entity_id, p_details);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.append_audit(text, text, uuid, jsonb) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.append_audit(text, text, uuid, jsonb) TO authenticated;
