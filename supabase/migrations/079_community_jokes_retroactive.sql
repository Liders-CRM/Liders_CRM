-- Migration 079 (רטרואקטיבית): community_jokes
-- הטבלה, ה-RPCs וה-pg_cron הזה כבר רצים בפרודקשן (נוצרו ישירות מול ה-DB
-- בסשן קודם, בלי שנשמר קובץ מיגרציה בריפו). קובץ זה משחזר את המצב החי
-- לצורך מעקב גרסאות ותיעוד — אינו משנה דבר אם מורץ שוב.
--
-- ⚠️ נמצא בסשן 10/7/2026 (בדיקת מוכנות להשקה): פיצ'ר שלם מבחינת ה-backend
-- (סוכן שולח בדיחה → אישור אדמין/אוטומטי → XP), אבל אין לו שום ממשק
-- משתמש ב-index.html/admin.html — 0 בדיחות אושרו אי פעם. כנראה נבנה
-- באמצע ולא הושלם, או שהוחלט לא להמשיך בו. לא נמחק — מחכה להחלטה אם
-- להשלים את ה-UI או להסיר את התשתית.

CREATE TABLE IF NOT EXISTS public.community_jokes (
  id              UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  submitted_by    UUID        NOT NULL,
  tenant_id       UUID        REFERENCES public.tenants(id) ON DELETE SET NULL,
  submitter_name  TEXT        NOT NULL DEFAULT '',
  joke_text       TEXT        NOT NULL CHECK (char_length(trim(joke_text)) >= 20 AND char_length(joke_text) <= 1200),
  category        TEXT        NOT NULL DEFAULT 'general' CHECK (category IN ('realestate','realestate_lawyer','interior','general')),
  status          TEXT        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  xp_awarded      BOOLEAN     NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  approved_at     TIMESTAMPTZ
);

ALTER TABLE public.community_jokes ENABLE ROW LEVEL SECURITY;
-- אין policies בכוונה — גישה רק דרך ה-RPCs למטה (SECURITY DEFINER).

-- ── RPC: submit_community_joke — סוכן מחובר שולח בדיחה (עד 3/יום) ──────────
CREATE OR REPLACE FUNCTION public.submit_community_joke(p_text TEXT, p_category TEXT DEFAULT 'general')
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_tid     UUID;
  v_name    TEXT;
  v_today   INT;
  v_joke_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  SELECT COUNT(*) INTO v_today
  FROM community_jokes
  WHERE submitted_by = v_uid AND created_at >= CURRENT_DATE;

  IF v_today >= 3 THEN
    RETURN json_build_object('ok', false, 'reason', 'daily_limit');
  END IF;

  IF p_category NOT IN ('realestate','realestate_lawyer','interior','general') THEN
    p_category := 'general';
  END IF;

  SELECT a.tenant_id, a.name
  INTO v_tid, v_name
  FROM public.agents a
  WHERE a.auth_user_id = v_uid
  LIMIT 1;

  INSERT INTO public.community_jokes
    (submitted_by, tenant_id, submitter_name, joke_text, category)
  VALUES (v_uid, v_tid, COALESCE(v_name,''), p_text, p_category)
  RETURNING id INTO v_joke_id;

  RETURN json_build_object('ok', true, 'id', v_joke_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_community_joke(TEXT,TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.submit_community_joke(TEXT,TEXT) FROM anon;

-- ── RPC: admin_list/approve/reject_community_joke — מוגנות ב-PIN (verify_admin_pin) ──
CREATE OR REPLACE FUNCTION public.admin_list_community_jokes(p_pin TEXT)
RETURNS TABLE(id UUID, joke_text TEXT, category TEXT, submitter_name TEXT, status TEXT, xp_awarded BOOLEAN, created_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (SELECT public.verify_admin_pin(p_pin)) THEN
    RAISE EXCEPTION 'invalid_pin';
  END IF;
  RETURN QUERY
    SELECT cj.id, cj.joke_text, cj.category, cj.submitter_name,
           cj.status, cj.xp_awarded, cj.created_at
    FROM community_jokes cj
    ORDER BY
      CASE cj.status WHEN 'pending' THEN 0 WHEN 'approved' THEN 1 ELSE 2 END,
      cj.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_community_jokes(TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_list_community_jokes(TEXT) FROM anon;

CREATE OR REPLACE FUNCTION public.admin_approve_community_joke(p_pin TEXT, p_joke_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_joke  community_jokes;
  v_today INT;
BEGIN
  IF NOT (SELECT public.verify_admin_pin(p_pin)) THEN
    RETURN json_build_object('ok', false, 'reason', 'invalid_pin');
  END IF;

  SELECT * INTO v_joke FROM community_jokes WHERE id = p_joke_id;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'reason', 'not_found');
  END IF;
  IF v_joke.status <> 'pending' THEN
    RETURN json_build_object('ok', false, 'reason', 'already_processed');
  END IF;

  SELECT COUNT(*) INTO v_today
  FROM community_jokes
  WHERE submitted_by = v_joke.submitted_by
    AND status = 'approved'
    AND approved_at >= CURRENT_DATE;

  IF v_today >= 1 THEN
    RETURN json_build_object('ok', false, 'reason', 'daily_limit_reached',
      'message', 'המשתמש כבר קיבל אישור לבדיחה אחת היום');
  END IF;

  UPDATE community_jokes
  SET status = 'approved', approved_at = now()
  WHERE id = p_joke_id;

  RETURN json_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_approve_community_joke(TEXT,UUID) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_approve_community_joke(TEXT,UUID) FROM anon;

CREATE OR REPLACE FUNCTION public.admin_reject_community_joke(p_pin TEXT, p_joke_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (SELECT public.verify_admin_pin(p_pin)) THEN
    RETURN json_build_object('ok', false, 'reason', 'invalid_pin');
  END IF;

  UPDATE community_jokes
  SET status = 'rejected'
  WHERE id = p_joke_id AND status = 'pending';

  RETURN json_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_reject_community_joke(TEXT,UUID) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_reject_community_joke(TEXT,UUID) FROM anon;

-- ── RPC: auto_approve_joke — אישור בודד (לא בשימוש כרגע, ללא grant לציבור) ──
CREATE OR REPLACE FUNCTION public.auto_approve_joke(p_joke_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_joke  community_jokes;
  v_today INT;
BEGIN
  SELECT * INTO v_joke FROM community_jokes WHERE id = p_joke_id;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'reason', 'not_found');
  END IF;
  IF v_joke.status <> 'pending' THEN
    RETURN json_build_object('ok', false, 'reason', 'already_processed');
  END IF;

  SELECT COUNT(*) INTO v_today
  FROM community_jokes
  WHERE submitted_by = v_joke.submitted_by
    AND status = 'approved'
    AND approved_at >= CURRENT_DATE;

  IF v_today >= 1 THEN
    RETURN json_build_object('ok', false, 'reason', 'daily_limit_reached');
  END IF;

  UPDATE community_jokes
  SET status = 'approved', approved_at = now()
  WHERE id = p_joke_id;

  RETURN json_build_object('ok', true);
END;
$$;

-- ── RPC: list_approved_jokes — ציבורי (anon), מציג בדיחות מאושרות בלבד ─────
CREATE OR REPLACE FUNCTION public.list_approved_jokes()
RETURNS TABLE(id UUID, joke_text TEXT, category TEXT, submitter_name TEXT, approved_at TIMESTAMPTZ)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, joke_text, category, submitter_name, approved_at
  FROM community_jokes
  WHERE status = 'approved'
  ORDER BY approved_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.list_approved_jokes() TO anon, authenticated;

-- ── RPC: pull_joke_approval_xp — מסמן בדיחות מאושרות כ"נלקח XP" ────────────
CREATE OR REPLACE FUNCTION public.pull_joke_approval_xp()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid   UUID := auth.uid();
  v_count INT;
BEGIN
  IF v_uid IS NULL THEN RETURN 0; END IF;

  UPDATE community_jokes
  SET xp_awarded = true
  WHERE submitted_by = v_uid
    AND status = 'approved'
    AND xp_awarded = false;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.pull_joke_approval_xp() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.pull_joke_approval_xp() FROM anon;

-- ── RPC: auto_approve_daily_jokes — pg_cron בלבד, admin only ───────────────
CREATE OR REPLACE FUNCTION public.auto_approve_daily_jokes()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_joke       RECORD;
  v_daily_cnt  INT;
BEGIN
  FOR v_joke IN
    SELECT id, submitted_by, joke_text
    FROM public.community_jokes
    WHERE status = 'pending'
    ORDER BY created_at ASC
    LIMIT 50
  LOOP
    SELECT COUNT(*) INTO v_daily_cnt
    FROM public.community_jokes
    WHERE submitted_by = v_joke.submitted_by
      AND status = 'approved'
      AND approved_at >= CURRENT_DATE;

    IF v_daily_cnt >= 1 THEN
      CONTINUE;
    END IF;

    IF length(trim(v_joke.joke_text)) BETWEEN 20 AND 1200 THEN
      UPDATE public.community_jokes
      SET status      = 'approved',
          approved_at = NOW(),
          xp_awarded  = false
      WHERE id = v_joke.id
        AND status = 'pending';
    END IF;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_approve_daily_jokes() TO postgres, service_role;
REVOKE EXECUTE ON FUNCTION public.auto_approve_daily_jokes() FROM anon, authenticated;

DO $$ BEGIN
  PERFORM cron.unschedule('auto-approve-daily-jokes');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 07:00 UTC = 10:00 שעון ישראל (קיץ UTC+3)
SELECT cron.schedule(
  'auto-approve-daily-jokes',
  '0 7 * * *',
  $$SELECT public.auto_approve_daily_jokes()$$
);
