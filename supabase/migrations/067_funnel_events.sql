-- Migration 067: funnel_events table + track_funnel_event RPC
-- שכבת מדידה ל-CRO: אירועי funnel מה-landing ומה-app נאספים כאן.
-- RLS: כתיבה לאנון, קריאה רק דרך RPC של SECURITY DEFINER (אדמין בלבד).

CREATE TABLE IF NOT EXISTS public.funnel_events (
  id           UUID         DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id   TEXT         NOT NULL,
  tenant_id    UUID,
  event_name   TEXT         NOT NULL,
  event_data   JSONB        DEFAULT '{}'::jsonb,
  created_at   TIMESTAMPTZ  DEFAULT now()
);

ALTER TABLE public.funnel_events ENABLE ROW LEVEL SECURITY;

-- כל אחד יכול לכתוב אירועים (visitors + users)
CREATE POLICY "funnel_events_insert_anon"
  ON public.funnel_events FOR INSERT
  TO anon WITH CHECK (true);

-- users מחוברים יכולים לכתוב גם הם
CREATE POLICY "funnel_events_insert_auth"
  ON public.funnel_events FOR INSERT
  TO authenticated WITH CHECK (true);

-- אין SELECT ישיר — קריאה רק דרך RPCs של SECURITY DEFINER למטה

-- ── RPC: track_funnel_event ──────────────────────────────────────────────────
-- קל-משקל: INSERT בלבד, ללא הרשאות קריאה, anon-safe.
CREATE OR REPLACE FUNCTION public.track_funnel_event(
  p_session_id TEXT,
  p_event_name TEXT,
  p_event_data JSONB DEFAULT '{}'::jsonb,
  p_tenant_id  UUID  DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- פסילת שמות אירוע חריגים (הגנת XSS בסיסית)
  IF length(p_event_name) > 80 OR p_event_name !~ '^[a-z_]+$' THEN
    RETURN;
  END IF;
  INSERT INTO funnel_events (session_id, tenant_id, event_name, event_data)
  VALUES (p_session_id, p_tenant_id, p_event_name, COALESCE(p_event_data, '{}'));
END;
$$;

GRANT EXECUTE ON FUNCTION public.track_funnel_event(TEXT, TEXT, JSONB, UUID) TO anon;
GRANT EXECUTE ON FUNCTION public.track_funnel_event(TEXT, TEXT, JSONB, UUID) TO authenticated;

-- ── RPC: get_funnel_summary (admin only) ─────────────────────────────────────
-- מחזיר ספירות של אירועי funnel ל-N ימים אחרונים לצגייה בטאב CRO.
CREATE OR REPLACE FUNCTION public.get_funnel_summary(p_days INT DEFAULT 7)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_since TIMESTAMPTZ := now() - (p_days || ' days')::interval;
  v_result JSONB;
BEGIN
  -- גישה מותרת רק ל-postgres (admin)
  IF current_role NOT IN ('postgres', 'service_role') THEN
    RAISE EXCEPTION 'admin only';
  END IF;

  SELECT jsonb_build_object(
    'period_days',       p_days,
    'landing_cta_clicks', (SELECT count(*) FROM funnel_events WHERE event_name='landing_cta_click' AND created_at >= v_since),
    'login_views',        (SELECT count(*) FROM funnel_events WHERE event_name='login_screen_view'  AND created_at >= v_since),
    'signup_completed',   (SELECT count(*) FROM funnel_events WHERE event_name='signup_completed'   AND created_at >= v_since),
    'signup_google',      (SELECT count(*) FROM funnel_events WHERE event_name='signup_method_chosen' AND event_data->>'method'='google' AND created_at >= v_since),
    'signup_email',       (SELECT count(*) FROM funnel_events WHERE event_name='signup_method_chosen' AND event_data->>'method'='email'  AND created_at >= v_since),
    'onboarding_done',    (SELECT count(*) FROM funnel_events WHERE event_name='onboarding_step_completed' AND (event_data->>'step')::int = 4 AND created_at >= v_since),
    'onboarding_abandoned',(SELECT count(*) FROM funnel_events WHERE event_name='onboarding_abandoned' AND created_at >= v_since),
    'top_abandon_step',   (SELECT event_data->>'step' FROM funnel_events WHERE event_name='onboarding_abandoned' AND created_at >= v_since GROUP BY event_data->>'step' ORDER BY count(*) DESC LIMIT 1),
    'upgrade_intents',    (SELECT count(*) FROM funnel_events WHERE event_name='upgrade_intent' AND created_at >= v_since),
    'demo_lock_hits',     (SELECT count(*) FROM funnel_events WHERE event_name='demo_lock_hit'  AND created_at >= v_since),
    'demo_to_signup',     (SELECT count(*) FROM funnel_events WHERE event_name='demo_to_signup' AND created_at >= v_since),
    'cta_breakdown',      (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('section', event_data->>'section', 'clicks', cnt) ORDER BY cnt DESC), '[]')
      FROM (
        SELECT event_data->>'section' AS section, count(*)::int AS cnt
        FROM funnel_events
        WHERE event_name = 'landing_cta_click' AND created_at >= v_since
        GROUP BY event_data->>'section'
      ) x
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_funnel_summary(INT) TO postgres;
GRANT EXECUTE ON FUNCTION public.get_funnel_summary(INT) TO service_role;
