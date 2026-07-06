-- Migration 051: enforce the motivation-agent's progressive cooldown
-- (90/120/150/180 min between uses) server-side, in addition to the
-- existing daily count cap. Previously the cooldown timer only lived in
-- the browser's localStorage, so clearing storage (incognito, another
-- browser, another device) let a user skip the wait between uses - the
-- daily count itself was never bypassable since that's already tracked
-- here, but the pacing was. The client-side countdown UI is unchanged
-- (it's just a nice display); this migration makes the server the actual
-- authority so the wait can't be skipped no matter what the client does.

ALTER TABLE ai_usage ADD COLUMN IF NOT EXISTS motivation_last_used_at timestamptz;

CREATE OR REPLACE FUNCTION public.check_and_increment_ai_usage(p_type text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid   uuid := auth.uid();
  v_email text := auth.email();
  v_plan  text;
  v_limit int;
  v_count int;
  v_last_motivation timestamptz;
  v_cooldown_min int;
  v_wait_seconds int;
  v_limits constant jsonb := '{
    "trial":    {"general":2,  "marketing":3,  "quicklog":3,  "support":2,  "motivation":2},
    "basic":    {"general":5,  "marketing":8,  "quicklog":15, "support":8,  "motivation":3},
    "pro":      {"general":10, "marketing":15, "quicklog":30, "support":15, "motivation":3},
    "premium":  {"general":20, "marketing":25, "quicklog":50, "support":25, "motivation":3},
    "lifetime": {"general":20, "marketing":25, "quicklog":50, "support":25, "motivation":3},
    "cancelled":{"general":0,  "marketing":0,  "quicklog":0,  "support":0,  "motivation":0}
  }';
BEGIN
  IF p_type NOT IN ('general','marketing','quicklog','support','motivation') THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'invalid_type');
  END IF;

  IF v_email IN ('liders.crm@gmail.com', 'elgrablidudu@gmail.com') THEN
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

  v_limit := COALESCE((v_limits -> v_plan -> p_type)::int, 2);

  INSERT INTO ai_usage (user_id, usage_date)
  VALUES (v_uid, CURRENT_DATE)
  ON CONFLICT (user_id, usage_date) DO NOTHING;

  SELECT CASE p_type
    WHEN 'general'    THEN general
    WHEN 'marketing'  THEN marketing
    WHEN 'quicklog'   THEN quicklog
    WHEN 'support'    THEN support
    WHEN 'motivation' THEN motivation
  END, motivation_last_used_at
  INTO v_count, v_last_motivation
  FROM ai_usage
  WHERE user_id = v_uid AND usage_date = CURRENT_DATE
  FOR UPDATE;

  IF v_count >= v_limit THEN
    RETURN jsonb_build_object('allowed', false, 'used', v_count, 'limit', v_limit, 'plan', v_plan);
  END IF;

  -- Progressive cooldown, motivation only: mirrors the client's
  -- _COOLDOWNS_MIN = [90,120,150,180] schedule (minutes to wait before
  -- the next use, based on how many uses already happened today).
  IF p_type = 'motivation' AND v_count >= 1 AND v_last_motivation IS NOT NULL THEN
    v_cooldown_min := (ARRAY[90,120,150,180])[LEAST(GREATEST(v_count,1),4)];
    IF now() < v_last_motivation + make_interval(mins => v_cooldown_min) THEN
      v_wait_seconds := CEIL(EXTRACT(EPOCH FROM (v_last_motivation + make_interval(mins => v_cooldown_min) - now())));
      RETURN jsonb_build_object('allowed', false, 'reason', 'cooling_down', 'retry_after_seconds', v_wait_seconds);
    END IF;
  END IF;

  UPDATE ai_usage SET
    general    = general    + CASE WHEN p_type = 'general'    THEN 1 ELSE 0 END,
    marketing  = marketing  + CASE WHEN p_type = 'marketing'  THEN 1 ELSE 0 END,
    quicklog   = quicklog   + CASE WHEN p_type = 'quicklog'   THEN 1 ELSE 0 END,
    support    = support    + CASE WHEN p_type = 'support'    THEN 1 ELSE 0 END,
    motivation = motivation + CASE WHEN p_type = 'motivation' THEN 1 ELSE 0 END,
    motivation_last_used_at = CASE WHEN p_type = 'motivation' THEN now() ELSE motivation_last_used_at END
  WHERE user_id = v_uid AND usage_date = CURRENT_DATE;

  RETURN jsonb_build_object('allowed', true, 'used', v_count + 1, 'limit', v_limit, 'plan', v_plan);
END;
$$;
