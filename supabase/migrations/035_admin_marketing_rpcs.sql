-- Migration 035: admin RPC to toggle marketing addon per tenant
CREATE OR REPLACE FUNCTION public.admin_toggle_marketing_addon(
  p_tenant_id uuid,
  p_enabled   boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  UPDATE tenants
  SET marketing_addon = p_enabled
  WHERE id = p_tenant_id;
END;
$$;

-- Migration 035b: admin RPC to extend trial
CREATE OR REPLACE FUNCTION public.admin_extend_trial(
  p_tenant_id uuid,
  p_days      int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  UPDATE tenants
  SET trial_ends_at = GREATEST(COALESCE(trial_ends_at, now()), now()) + (p_days || ' days')::interval,
      plan          = 'trial'
  WHERE id = p_tenant_id;
END;
$$;

-- Migration 035c: admin RPC to set internal notes
CREATE OR REPLACE FUNCTION public.admin_set_tenant_notes(
  p_tenant_id uuid,
  p_notes     text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  UPDATE tenants SET notes = p_notes WHERE id = p_tenant_id;
END;
$$;
