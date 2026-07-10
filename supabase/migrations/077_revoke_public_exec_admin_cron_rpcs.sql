-- Migration 077: סגירת גישת anon/authenticated לפונקציות admin/cron פנימיות
-- Supabase מעניק כברירת מחדל EXECUTE ל-anon ו-authenticated על כל פונקציה
-- חדשה בסכימת public (בנוסף ל-PUBLIC הרגיל) — הפונקציות הבאות סמכו רק על
-- GRANT ל-postgres/service_role בלי REVOKE מפורש, ולכן היו קריאות בפועל
-- דרך /rest/v1/rpc/<name> על ידי כל אחד באינטרנט, ללא צורך בהתחברות.
--
-- admin_list_ab_tests / admin_upsert_ab_test / get_funnel_summary: מוגנות
--   גם ב-runtime guard (current_role NOT IN ('postgres','service_role')) —
--   לא הייתה חשיפת מידע בפועל, אבל תוקן לפי best practice.
-- send_daily_lead_digest / send_cro_weekly_digest / auto_approve_daily_jokes:
--   לא היה שום guard פנימי — כל אחד יכול היה להפעיל אותן ידנית (ספאם
--   webhook, אישור בדיחות מוקדם).

REVOKE EXECUTE ON FUNCTION public.send_daily_lead_digest() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.send_cro_weekly_digest() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.auto_approve_daily_jokes() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_list_ab_tests() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_upsert_ab_test(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_funnel_summary(INT) FROM anon, authenticated;
