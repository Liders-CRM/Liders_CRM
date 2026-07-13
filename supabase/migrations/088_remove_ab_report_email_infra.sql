-- Migration 088: הסרת תשתית דוח ה-CRO השבועי למייל (הוחלט מול המשתמש 13/7/2026)
--
-- המשתמש החליט לא לתחזק את חיבור ה-Gmail (refresh token פג כל 7 ימים כל עוד
-- ה-OAuth consent screen במצב Testing) רק בשביל דוח אוטומטי למייל שאינו הכרחי.
-- מנוע ה-A/B testing עצמו (cro_ab_tests, get_active_ab_tests, admin_list_ab_tests,
-- admin_upsert_ab_test, ABEngine ב-landing.html/index.html) **נשאר פעיל במלואו**
-- ונבדק ידנית דרך admin.html — רק שכבת הדיווח האוטומטי למייל מוסרת.
--
-- מוסר:
--   1. cron plto-ab-report-weekly (086)
--   2. send_ab_test_report_email() (086)
--   3. verify_cron_report_secret() (086/087) — משאיר את ה-Edge Function
--      cro-report-email בפריסה (אין כלי להסיר Edge Function בעצמי) אבל בלי
--      שום דרך לאמת מולה מעכשיו, כלומר היא מנוטרלת לגמרי בפועל.
--   4. Vault secret cro_report_internal_secret — היה משמש רק לאימות מול ה-
--      Edge Function שהוסרה.
--   5. send_cro_weekly_digest() (069) — שריד מת נוסף: ה-cron שלו כבר בוטל
--      במיגרציה 086 (הוחלף בזמנו ב-send_ab_test_report_email), אבל הפונקציה
--      עצמה נשארה מוגדרת בלי קורא. מוסרת עכשיו יחד עם שאר השאריות מאותו נושא.

DO $$ BEGIN
  PERFORM cron.unschedule('plto-ab-report-weekly');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DROP FUNCTION IF EXISTS public.send_ab_test_report_email();
DROP FUNCTION IF EXISTS public.verify_cron_report_secret(TEXT);
DROP FUNCTION IF EXISTS public.send_cro_weekly_digest();

DELETE FROM vault.secrets WHERE name = 'cro_report_internal_secret';
