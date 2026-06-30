-- Migration 041: Server-side AI quota enforcement
-- Moves daily AI usage tracking from client localStorage to the DB so
-- it cannot be bypassed by clearing localStorage or manipulating DevTools.

CREATE TABLE IF NOT EXISTS public.ai_usage (
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  usage_date   date NOT NULL DEFAULT CURRENT_DATE,
  general      int  NOT NULL DEFAULT 0,
  marketing    int  NOT NULL DEFAULT 0,
  quicklog     int  NOT NULL DEFAULT 0,
  support      int  NOT NULL DEFAULT 0,
  motivation   int  NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, usage_date)
);

ALTER TABLE public.ai_usage ENABLE ROW LEVEL SECURITY;

-- Users can only see their own rows (for client-side display)
CREATE POLICY "ai_usage_own_read" ON public.ai_usage
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- ── Atomic check-and-increment RPC ───────────────────────────────────────────
-- Called from ai-proxy Edge Function (with the user's JWT) before each API call.
-- Uses SELECT ... FOR UPDATE to prevent race conditions.
-- Returns: {allowed: bool, used: int, limit: int, plan: text}

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
  v_limits constant jsonb := '{
    "trial":    {"general":2,  "marketing":3,  "quicklog":3,  "support":2,  "motivation":2},
    "basic":    {"general":5,  "marketing":8,  "quicklog":15, "support":8,  "motivation":3},
    "pro":      {"general":10, "marketing":15, "quicklog":30, "support":15, "motivation":3},
    "premium":  {"general":20, "marketing":25, "quicklog":50, "support":25, "motivation":3},
    "lifetime": {"general":20, "marketing":25, "quicklog":50, "support":25, "motivation":3},
    "cancelled":{"general":0,  "marketing":0,  "quicklog":0,  "support":0,  "motivation":0}
  }';
BEGIN
  -- Validate type to prevent SQL manipulation
  IF p_type NOT IN ('general','marketing','quicklog','support','motivation') THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'invalid_type');
  END IF;

  -- Admin bypass (never blocked)
  IF v_email IN ('liders.crm@gmail.com', 'elgrablidudu@gmail.com') THEN
    RETURN jsonb_build_object('allowed', true, 'plan', 'internal', 'admin', true);
  END IF;

  -- Resolve tenant plan
  SELECT t.plan INTO v_plan
  FROM agent_users a
  JOIN tenants t ON t.id = a.tenant_id
  WHERE a.auth_user_id = v_uid
  LIMIT 1;

  IF v_plan IS NULL OR v_plan = 'cancelled' THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'no_active_plan');
  END IF;

  v_limit := COALESCE((v_limits -> v_plan -> p_type)::int, 2);

  -- Ensure today's row exists
  INSERT INTO ai_usage (user_id, usage_date)
  VALUES (v_uid, CURRENT_DATE)
  ON CONFLICT (user_id, usage_date) DO NOTHING;

  -- Lock the row and read current count
  SELECT CASE p_type
    WHEN 'general'    THEN general
    WHEN 'marketing'  THEN marketing
    WHEN 'quicklog'   THEN quicklog
    WHEN 'support'    THEN support
    WHEN 'motivation' THEN motivation
  END INTO v_count
  FROM ai_usage
  WHERE user_id = v_uid AND usage_date = CURRENT_DATE
  FOR UPDATE;

  -- Enforce limit
  IF v_count >= v_limit THEN
    RETURN jsonb_build_object('allowed', false, 'used', v_count, 'limit', v_limit, 'plan', v_plan);
  END IF;

  -- Atomic increment for the correct column
  UPDATE ai_usage SET
    general    = general    + CASE WHEN p_type = 'general'    THEN 1 ELSE 0 END,
    marketing  = marketing  + CASE WHEN p_type = 'marketing'  THEN 1 ELSE 0 END,
    quicklog   = quicklog   + CASE WHEN p_type = 'quicklog'   THEN 1 ELSE 0 END,
    support    = support    + CASE WHEN p_type = 'support'    THEN 1 ELSE 0 END,
    motivation = motivation + CASE WHEN p_type = 'motivation' THEN 1 ELSE 0 END
  WHERE user_id = v_uid AND usage_date = CURRENT_DATE;

  RETURN jsonb_build_object('allowed', true, 'used', v_count + 1, 'limit', v_limit, 'plan', v_plan);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_and_increment_ai_usage(text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.check_and_increment_ai_usage(text) TO authenticated;
