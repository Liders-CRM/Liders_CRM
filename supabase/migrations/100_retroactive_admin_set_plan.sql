-- Migration 096: Retroactively document admin_set_plan() (drift fix)
--
-- admin_set_plan(p_tenant_id, p_plan, p_trial_ends_at) is called live from
-- admin.html (grantFreePlan/resetToTrial) and referenced by name in migration
-- 044's comment, but it has NO migration file anywhere in this repo — it was
-- created directly against the production database, the same kind of drift
-- already documented for gmail-proxy/community_jokes (see CLAUDE.md session
-- 10/7/2026(ב)). Pulled verbatim via pg_get_functiondef() against the live
-- project on 17/7/2026 before building a trigger on top of it (096+), so the
-- trigger's assumption of a plain `UPDATE tenants SET plan = ...` is verified,
-- not guessed. This migration changes nothing — CREATE OR REPLACE against the
-- exact live definition.

CREATE OR REPLACE FUNCTION public.admin_set_plan(
  p_tenant_id uuid,
  p_plan text,
  p_trial_ends_at timestamptz DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_caller text := auth.email();
BEGIN
  IF v_caller NOT IN ('info@plto.app', 'elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;
  IF p_plan NOT IN ('trial', 'basic', 'pro', 'premium', 'internal', 'lifetime') THEN
    RAISE EXCEPTION 'invalid plan: %', p_plan;
  END IF;
  UPDATE tenants
    SET plan            = p_plan,
        trial_ends_at   = p_trial_ends_at
  WHERE id = p_tenant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'tenant not found';
  END IF;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.admin_set_plan(uuid, text, timestamptz) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.admin_set_plan(uuid, text, timestamptz) TO authenticated;
