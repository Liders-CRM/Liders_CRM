-- Migration 022: Admin RPC — get_saas_tenants_admin
-- מאפשר לאדמינים לקרוא את כל הטנאנטים + סטטיסטיקות
CREATE OR REPLACE FUNCTION public.get_saas_tenants_admin()
RETURNS TABLE (
  id            uuid,
  name          text,
  billing_email text,
  plan          text,
  trial_ends_at timestamptz,
  created_at    timestamptz,
  lead_count    bigint,
  task_count    bigint,
  agent_count   bigint
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
  SELECT
    t.id,
    t.name,
    t.billing_email,
    t.plan,
    t.trial_ends_at,
    t.created_at,
    (SELECT COUNT(*) FROM leads l WHERE l.tenant_id = t.id)::bigint,
    (SELECT COUNT(*) FROM tasks tk WHERE tk.tenant_id = t.id)::bigint,
    (SELECT COUNT(*) FROM agent_users au WHERE au.tenant_id = t.id)::bigint
  FROM tenants t
  ORDER BY t.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_saas_tenants_admin() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_saas_tenants_admin() FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_saas_tenants_admin() TO authenticated;
