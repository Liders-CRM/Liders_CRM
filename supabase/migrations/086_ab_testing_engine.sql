-- Migration 086: A/B testing engine (real variant serving) + automated weekly
-- report email sent directly from Supabase.
--
-- מוסיף:
--   1. cro_ab_tests.test_key — מזהה יציב שהקוד בפרונט (landing.html/index.html)
--      מחפש לפיו איזה טסט לרנדר. NULL = טסט "רעיון בלבד" בלי חיווט טכני עדיין.
--   2. get_active_ab_tests() מחדש — ציבורי (anon+authenticated), מחזיר את תוכן
--      הוריאנטים בפועל (לא רק שם) לטסטים פעילים, לפי test_key.
--   3. admin_upsert_ab_test / admin_list_ab_tests — עודכנו לתמוך ב-test_key.
--   4. Vault secret + verify_cron_report_secret() — אימות פנימי בין ה-cron
--      ל-Edge Function החדשה (cro-report-email). אין secret חדש להגדיר ידנית
--      ב-Dashboard: ה-Edge Function קוראת את הערך דרך RPC עם ה-service_role
--      key שכבר מוזרק אוטומטית לכל Edge Function.
--   5. send_ab_test_report_email() — בונה דוח HTML (סיכום funnel + טבלת A/B)
--      ושולח ל-Edge Function החדשה במקום ל-Make webhook הישן: לסצנריות
--      הקיימות ב-Make (Lead Notifications, Trial Expiry) אין route שמאזין
--      ל-event=cro.weekly_digest, כך שהדוח השבועי הלך לאיבוד שבועות.
--   6. cron: מבטל את הדוח הישן, מתזמן את החדש לאותו זמן (יום ראשון 08:00 UTC).

-- ── 1. עמודה חדשה ─────────────────────────────────────────────────────────────
ALTER TABLE public.cro_ab_tests
  ADD COLUMN IF NOT EXISTS test_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS cro_ab_tests_test_key_uq
  ON public.cro_ab_tests (test_key) WHERE test_key IS NOT NULL;

-- ── 2. get_active_ab_tests — ציבורי, מחזיר תוכן הוריאנטים בפועל ────────────────
CREATE OR REPLACE FUNCTION public.get_active_ab_tests()
RETURNS TABLE (id UUID, test_key TEXT, variant_a TEXT, variant_b TEXT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT t.id, t.test_key, t.variant_a, t.variant_b
  FROM cro_ab_tests t
  WHERE t.status = 'active' AND t.test_key IS NOT NULL;
$$;

GRANT EXECUTE ON FUNCTION public.get_active_ab_tests() TO anon;
GRANT EXECUTE ON FUNCTION public.get_active_ab_tests() TO authenticated;

-- ── 3. admin_list_ab_tests / admin_upsert_ab_test — הוספת test_key ────────────
-- DROP מפורש כי סוג ההחזרה (עמודות OUT) משתנה — CREATE OR REPLACE לא תומך בזה.
DROP FUNCTION IF EXISTS public.admin_list_ab_tests();

CREATE OR REPLACE FUNCTION public.admin_list_ab_tests()
RETURNS TABLE (
  id UUID, name TEXT, hypothesis TEXT,
  test_key TEXT,
  variant_a TEXT, variant_b TEXT,
  status TEXT, winner TEXT,
  started_at TIMESTAMPTZ, ended_at TIMESTAMPTZ, created_at TIMESTAMPTZ,
  exposures_a BIGINT, exposures_b BIGINT,
  conversions_a BIGINT, conversions_b BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF current_role NOT IN ('postgres', 'service_role') THEN
    RAISE EXCEPTION 'admin only';
  END IF;
  RETURN QUERY
  SELECT
    t.id, t.name, t.hypothesis, t.test_key,
    t.variant_a, t.variant_b,
    t.status, t.winner,
    t.started_at, t.ended_at, t.created_at,
    (SELECT count(*) FROM funnel_events e WHERE e.event_name='ab_exposure'   AND e.event_data->>'test_id'=t.id::text AND e.event_data->>'variant'='a'),
    (SELECT count(*) FROM funnel_events e WHERE e.event_name='ab_exposure'   AND e.event_data->>'test_id'=t.id::text AND e.event_data->>'variant'='b'),
    (SELECT count(*) FROM funnel_events e WHERE e.event_name='ab_converted'  AND e.event_data->>'test_id'=t.id::text AND e.event_data->>'variant'='a'),
    (SELECT count(*) FROM funnel_events e WHERE e.event_name='ab_converted'  AND e.event_data->>'test_id'=t.id::text AND e.event_data->>'variant'='b')
  FROM cro_ab_tests t
  ORDER BY
    CASE t.status WHEN 'active' THEN 0 WHEN 'backlog' THEN 1 ELSE 2 END,
    t.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_ab_tests() TO postgres;
GRANT EXECUTE ON FUNCTION public.admin_list_ab_tests() TO service_role;

CREATE OR REPLACE FUNCTION public.admin_upsert_ab_test(
  p_id         UUID,
  p_name       TEXT,
  p_hypothesis TEXT,
  p_variant_a  TEXT,
  p_variant_b  TEXT,
  p_status     TEXT,
  p_winner     TEXT DEFAULT NULL,
  p_test_key   TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  IF current_role NOT IN ('postgres', 'service_role') THEN
    RAISE EXCEPTION 'admin only';
  END IF;
  IF p_id IS NOT NULL THEN
    UPDATE cro_ab_tests SET
      name       = COALESCE(p_name, name),
      hypothesis = COALESCE(p_hypothesis, hypothesis),
      variant_a  = COALESCE(p_variant_a, variant_a),
      variant_b  = COALESCE(p_variant_b, variant_b),
      status     = COALESCE(p_status, status),
      winner     = p_winner,
      test_key   = COALESCE(p_test_key, test_key),
      started_at = CASE WHEN p_status='active'    AND started_at IS NULL THEN now() ELSE started_at END,
      ended_at   = CASE WHEN p_status='concluded' AND ended_at   IS NULL THEN now() ELSE ended_at   END
    WHERE id = p_id
    RETURNING id INTO v_id;
  ELSE
    INSERT INTO cro_ab_tests (name, hypothesis, variant_a, variant_b, status, winner, test_key)
    VALUES (p_name, p_hypothesis, p_variant_a, p_variant_b, COALESCE(p_status,'backlog'), p_winner, p_test_key)
    RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_upsert_ab_test(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) TO postgres;
GRANT EXECUTE ON FUNCTION public.admin_upsert_ab_test(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) TO service_role;

-- מחיקת ה-overload הישן (7 פרמטרים, בלי test_key) — כדי לא להשאיר שני overloads
-- כמו שכבר קרה וטופל במיגרציה 080 עם ה-referral RPCs.
DROP FUNCTION IF EXISTS public.admin_upsert_ab_test(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT);

-- ── 4. Vault secret + verify_cron_report_secret ────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'cro_report_internal_secret') THEN
    PERFORM vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'cro_report_internal_secret',
      'Shared secret: pg_cron -> cro-report-email Edge Function auth. Not used by any client.'
    );
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.verify_cron_report_secret(p_secret TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- רק Edge Functions (עם ה-service_role key שמוזרק אוטומטית) יכולות לקרוא לזה.
  IF current_role NOT IN ('service_role') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM vault.decrypted_secrets
    WHERE name = 'cro_report_internal_secret' AND decrypted_secret = p_secret
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_cron_report_secret(TEXT) TO service_role;

-- ── 5. send_ab_test_report_email — בונה דוח HTML ושולח ל-Edge Function ─────────
CREATE OR REPLACE FUNCTION public.send_ab_test_report_email()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
DECLARE
  v_since      TIMESTAMPTZ := now() - interval '7 days';
  v_secret     TEXT;
  v_signups    INT;
  v_ob_done    INT;
  v_upgrades   INT;
  v_tests_html TEXT;
  v_html       TEXT;
BEGIN
  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets WHERE name = 'cro_report_internal_secret';

  IF v_secret IS NULL THEN
    RAISE WARNING 'send_ab_test_report_email: internal secret missing, skipping send';
    RETURN;
  END IF;

  SELECT count(*)::INT INTO v_signups
    FROM funnel_events WHERE event_name='signup_completed' AND created_at >= v_since;
  SELECT count(*)::INT INTO v_ob_done
    FROM funnel_events WHERE event_name='onboarding_step_completed'
      AND (event_data->>'step')::int = 4 AND created_at >= v_since;
  SELECT count(*)::INT INTO v_upgrades
    FROM funnel_events WHERE event_name='upgrade_intent' AND created_at >= v_since;

  SELECT COALESCE(string_agg(row_html, ''), '<tr><td colspan="5" style="padding:14px;color:#94A3B8;">אין ניסויי A/B פעילים כרגע</td></tr>')
  INTO v_tests_html
  FROM (
    SELECT format(
      '<tr>
         <td style="padding:8px 10px;border-bottom:1px solid #E2E8F0;">%s</td>
         <td style="padding:8px 10px;border-bottom:1px solid #E2E8F0;font-size:13px;color:#475569;">%s</td>
         <td style="padding:8px 10px;border-bottom:1px solid #E2E8F0;font-size:13px;color:#475569;">%s</td>
         <td style="padding:8px 10px;border-bottom:1px solid #E2E8F0;text-align:center;">%s / %s</td>
         <td style="padding:8px 10px;border-bottom:1px solid #E2E8F0;text-align:center;font-weight:700;">%s</td>
       </tr>',
      t.name,
      COALESCE(t.variant_a, '—'),
      COALESCE(t.variant_b, '—'),
      ea, eb,
      CASE WHEN ea > 0 AND eb > 0 THEN
        round((ca::numeric/ea)*100,1) || '% / ' || round((cb::numeric/eb)*100,1) || '%'
      ELSE 'אין מספיק נתונים עדיין' END
    ) AS row_html
    FROM cro_ab_tests t
    CROSS JOIN LATERAL (
      SELECT
        (SELECT count(*) FROM funnel_events e WHERE e.event_name='ab_exposure'  AND e.event_data->>'test_id'=t.id::text AND e.event_data->>'variant'='a') AS ea,
        (SELECT count(*) FROM funnel_events e WHERE e.event_name='ab_exposure'  AND e.event_data->>'test_id'=t.id::text AND e.event_data->>'variant'='b') AS eb,
        (SELECT count(*) FROM funnel_events e WHERE e.event_name='ab_converted' AND e.event_data->>'test_id'=t.id::text AND e.event_data->>'variant'='a') AS ca,
        (SELECT count(*) FROM funnel_events e WHERE e.event_name='ab_converted' AND e.event_data->>'test_id'=t.id::text AND e.event_data->>'variant'='b') AS cb
    ) x
    WHERE t.status IN ('active','concluded')
    ORDER BY t.created_at DESC
  ) rows;

  v_html := format(
    '<div style="font-family:Arial,sans-serif;direction:rtl;text-align:right;max-width:640px;margin:0 auto;">
       <h2 style="color:#0F1F3D;">📊 דוח CRO שבועי — PLTO</h2>
       <p style="color:#64748B;font-size:13px;">%s עד %s</p>
       <h3 style="color:#0F1F3D;margin-top:24px;">משפך כללי (7 ימים אחרונים)</h3>
       <table style="width:100%%;border-collapse:collapse;font-size:14px;">
         <tr><td style="padding:6px 10px;">הרשמות שהושלמו</td><td style="padding:6px 10px;font-weight:700;">%s</td></tr>
         <tr><td style="padding:6px 10px;">סיימו אונבורדינג</td><td style="padding:6px 10px;font-weight:700;">%s</td></tr>
         <tr><td style="padding:6px 10px;">כוונות שדרוג</td><td style="padding:6px 10px;font-weight:700;">%s</td></tr>
       </table>
       <h3 style="color:#0F1F3D;margin-top:24px;">ניסויי A/B (מצטבר, מאז תחילת כל ניסוי)</h3>
       <table style="width:100%%;border-collapse:collapse;font-size:14px;">
         <tr style="background:#F1F5F9;">
           <th style="padding:8px 10px;text-align:right;">ניסוי</th>
           <th style="padding:8px 10px;text-align:right;">A</th>
           <th style="padding:8px 10px;text-align:right;">B</th>
           <th style="padding:8px 10px;">חשיפות A/B</th>
           <th style="padding:8px 10px;">המרה A/B</th>
         </tr>
         %s
       </table>
       <p style="color:#94A3B8;font-size:12px;margin-top:20px;">דוח אוטומטי, נשלח כל יום ראשון מ-PLTO.</p>
     </div>',
    to_char(v_since AT TIME ZONE 'Asia/Jerusalem', 'DD/MM/YYYY'),
    to_char(now()   AT TIME ZONE 'Asia/Jerusalem', 'DD/MM/YYYY'),
    v_signups, v_ob_done, v_upgrades,
    v_tests_html
  );

  PERFORM net.http_post(
    url     := 'https://scyfywvzoogfrlalgftv.supabase.co/functions/v1/cro-report-email',
    headers := jsonb_build_object('Content-Type','application/json','x-report-secret', v_secret),
    body    := jsonb_build_object('subject', 'דוח CRO שבועי — PLTO', 'html', v_html)
  );
END;
$func$;

GRANT EXECUTE ON FUNCTION public.send_ab_test_report_email() TO postgres;

-- ── 6. Cron: מבטלים את הדוח הישן שהולך לאיבוד, מתזמנים את החדש ────────────────
DO $$ BEGIN
  PERFORM cron.unschedule('plto-cro-weekly-digest');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$ BEGIN
  PERFORM cron.unschedule('liders-cro-weekly-digest');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$ BEGIN
  PERFORM cron.unschedule('plto-ab-report-weekly');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

SELECT cron.schedule(
  'plto-ab-report-weekly',
  '0 8 * * 1',
  $$SELECT public.send_ab_test_report_email()$$
);
