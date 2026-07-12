-- Migration 084: weekly quota for AI-vision lead import from a photo/screenshot
-- ("lead_image_import" type in ai-proxy). Separate from ai_usage (041) because
-- this resets on a rolling 7-day window, not per calendar day, and is a flat
-- 2/week for every agent regardless of plan tier (see CLAUDE.md cost analysis).

CREATE TABLE IF NOT EXISTS public.lead_image_import_usage (
  id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  used_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lead_image_import_usage_user_time
  ON public.lead_image_import_usage (user_id, used_at DESC);

ALTER TABLE public.lead_image_import_usage ENABLE ROW LEVEL SECURITY;
-- No policies: reachable only through the SECURITY DEFINER RPCs below,
-- same pattern as ai_usage / lead_referrals / shared_leads.

CREATE OR REPLACE FUNCTION public.check_and_increment_lead_image_import()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_email  text := auth.email();
  v_plan   text;
  v_count  int;
  v_oldest timestamptz;
  v_limit  constant int := 2; -- flat 2/week across all plans
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'unauthenticated');
  END IF;

  IF v_email IN ('info@plto.app', 'elgrablidudu@gmail.com') THEN
    RETURN jsonb_build_object('allowed', true, 'plan', 'internal', 'admin', true);
  END IF;

  SELECT t.plan INTO v_plan
  FROM agent_users a
  JOIN tenants t ON t.id = a.tenant_id
  WHERE a.auth_user_id = v_uid
  LIMIT 1;

  IF v_plan IS NULL OR v_plan = 'cancelled' THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'no_active_plan');
  END IF;

  SELECT count(*), min(used_at) INTO v_count, v_oldest
  FROM lead_image_import_usage
  WHERE user_id = v_uid AND used_at > now() - interval '7 days';

  IF v_count >= v_limit THEN
    RETURN jsonb_build_object(
      'allowed', false, 'reason', 'weekly_limit',
      'used', v_count, 'limit', v_limit,
      'available_at', v_oldest + interval '7 days'
    );
  END IF;

  INSERT INTO lead_image_import_usage (user_id) VALUES (v_uid);

  RETURN jsonb_build_object('allowed', true, 'used', v_count + 1, 'limit', v_limit, 'plan', v_plan);
END;
$$;

-- Read-only status check (for showing "X/2 נותרו" before the user picks a file,
-- without spending one of their two weekly uses just to look).
CREATE OR REPLACE FUNCTION public.get_lead_image_import_quota()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_email  text := auth.email();
  v_count  int;
  v_oldest timestamptz;
  v_limit  constant int := 2;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('used', 0, 'limit', v_limit);
  END IF;

  IF v_email IN ('info@plto.app', 'elgrablidudu@gmail.com') THEN
    RETURN jsonb_build_object('used', 0, 'limit', 999, 'admin', true);
  END IF;

  SELECT count(*), min(used_at) INTO v_count, v_oldest
  FROM lead_image_import_usage
  WHERE user_id = v_uid AND used_at > now() - interval '7 days';

  RETURN jsonb_build_object(
    'used', COALESCE(v_count, 0), 'limit', v_limit,
    'available_at', CASE WHEN COALESCE(v_count,0) >= v_limit THEN v_oldest + interval '7 days' ELSE NULL END
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_and_increment_lead_image_import() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.check_and_increment_lead_image_import() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_lead_image_import_quota() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_lead_image_import_quota() TO authenticated;
