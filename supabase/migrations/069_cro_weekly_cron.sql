-- Migration 069: CRO weekly digest cron job
-- רץ כל ראשון 08:00 UTC = 11:00 ישראל (קיץ UTC+3).
-- שולח סיכום שבועי של נתוני ה-funnel ל-Make.com webhook (אותה כתובת קיימת).
-- Make.com מנתב לפי event='cro.weekly_digest' לסצנריו ייעודי.

CREATE OR REPLACE FUNCTION public.send_cro_weekly_digest()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
DECLARE
  v_since       TIMESTAMPTZ := now() - interval '7 days';
  v_signups     INT;
  v_ob_done     INT;
  v_upgrades    INT;
  v_demo_signup INT;
  v_top_abandon TEXT;
  v_conv_rate   TEXT;
BEGIN
  SELECT count(*)::INT INTO v_signups
    FROM funnel_events WHERE event_name='signup_completed' AND created_at >= v_since;

  SELECT count(*)::INT INTO v_ob_done
    FROM funnel_events WHERE event_name='onboarding_step_completed'
      AND (event_data->>'step')::int = 4 AND created_at >= v_since;

  SELECT count(*)::INT INTO v_upgrades
    FROM funnel_events WHERE event_name='upgrade_intent' AND created_at >= v_since;

  SELECT count(*)::INT INTO v_demo_signup
    FROM funnel_events WHERE event_name='demo_to_signup' AND created_at >= v_since;

  SELECT event_data->>'step' INTO v_top_abandon
    FROM funnel_events WHERE event_name='onboarding_abandoned' AND created_at >= v_since
    GROUP BY event_data->>'step' ORDER BY count(*) DESC LIMIT 1;

  -- שיעור המרה: signup → onboarding done
  IF v_signups > 0 THEN
    v_conv_rate := round((v_ob_done::numeric / v_signups) * 100, 1)::text || '%';
  ELSE
    v_conv_rate := 'אין נתונים';
  END IF;

  PERFORM net.http_post(
    url     := 'https://hook.eu1.make.com/f0nzngm6gdokri5naqu7enbay538ay8i',
    headers := '{"Content-Type":"application/json"}'::jsonb,
    body    := json_build_object(
      'event',         'cro.weekly_digest',
      'week_start',    to_char(v_since AT TIME ZONE 'Asia/Jerusalem', 'DD/MM/YYYY'),
      'week_end',      to_char(now() AT TIME ZONE 'Asia/Jerusalem', 'DD/MM/YYYY'),
      'signups',       v_signups,
      'onboarding_done', v_ob_done,
      'conversion_rate', v_conv_rate,
      'upgrade_intents', v_upgrades,
      'demo_to_signup',  v_demo_signup,
      'top_abandon_step', COALESCE(v_top_abandon, 'אין נטישות')
    )::text
  );
END;
$func$;

GRANT EXECUTE ON FUNCTION public.send_cro_weekly_digest() TO postgres;

-- הסרת עבודה קיימת אם יש (idempotent)
DO $$ BEGIN
  PERFORM cron.unschedule('liders-cro-weekly-digest');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- כל ראשון 08:00 UTC = 11:00 ישראל
SELECT cron.schedule(
  'liders-cro-weekly-digest',
  '0 8 * * 1',
  $$SELECT public.send_cro_weekly_digest()$$
);
