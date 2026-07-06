-- Migration 044: Fix missing admin-auth guard on 3 admin RPCs
--
-- Critical bug found via Supabase security advisor: admin_extend_trial,
-- admin_set_tenant_notes, and admin_toggle_marketing_addon are SECURITY
-- DEFINER functions exposed at /rest/v1/rpc/* with EXECUTE granted to the
-- `anon` role and NO internal authorization check — unlike every sibling
-- admin_* function (admin_get_accounts, admin_save_account, admin_set_plan,
-- admin_reply_support), which all guard with
-- `IF auth.email() NOT IN (...) THEN RAISE EXCEPTION`.
--
-- Net effect before this fix: any unauthenticated caller with the public
-- anon key (always public in a Supabase frontend) could call these three
-- RPCs directly to grant themselves/any tenant unlimited trial extensions,
-- enable the paid marketing addon for free, or vandalize tenant notes —
-- for ANY tenant_id, no login required.

CREATE OR REPLACE FUNCTION public.admin_extend_trial(p_tenant_id uuid, p_days integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_caller text := auth.email();
BEGIN
  IF v_caller NOT IN ('liders.crm@gmail.com', 'elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;
  UPDATE tenants
  SET trial_ends_at = GREATEST(COALESCE(trial_ends_at, now()), now()) + (p_days || ' days')::interval,
      plan = 'trial'
  WHERE id = p_tenant_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_tenant_notes(p_tenant_id uuid, p_notes text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_caller text := auth.email();
BEGIN
  IF v_caller NOT IN ('liders.crm@gmail.com', 'elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;
  UPDATE tenants SET notes = p_notes WHERE id = p_tenant_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_toggle_marketing_addon(p_tenant_id uuid, p_enabled boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_caller text := auth.email();
BEGIN
  IF v_caller NOT IN ('liders.crm@gmail.com', 'elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;
  UPDATE tenants SET marketing_addon = p_enabled WHERE id = p_tenant_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_extend_trial(uuid, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_set_tenant_notes(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_toggle_marketing_addon(uuid, boolean) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.admin_extend_trial(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_tenant_notes(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_toggle_marketing_addon(uuid, boolean) TO authenticated;
