-- Migration 078 (רטרואקטיבית): gmail_tokens
-- הטבלה, הטריגר והפונקציה הזו כבר רצים בפרודקשן (נוצרו ישירות מול ה-DB
-- בסשן קודם, בלי שנשמר קובץ מיגרציה בריפו). קובץ זה משחזר את המצב החי
-- לצורך מעקב גרסאות ותיעוד — אינו משנה דבר אם מורץ שוב (IF NOT EXISTS).
--
-- שימוש: מאחסן refresh_token/access_token ל-OAuth של liders.crm@gmail.com
-- (תיבת מייל משותפת של החברה, forwarding ל-info@plto.app), בשימוש
-- Edge Functions gmail-oauth-callback ו-gmail-proxy.

CREATE TABLE IF NOT EXISTS public.gmail_tokens (
  id            UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  account       TEXT        NOT NULL UNIQUE,
  refresh_token TEXT        NOT NULL,
  access_token  TEXT,
  expires_at    TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.gmail_tokens ENABLE ROW LEVEL SECURITY;
-- אין policies בכוונה — גישה רק דרך Edge Functions עם SUPABASE_SERVICE_ROLE_KEY.

CREATE OR REPLACE FUNCTION public.update_gmail_tokens_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS trg_gmail_tokens_updated_at ON public.gmail_tokens;
CREATE TRIGGER trg_gmail_tokens_updated_at
  BEFORE UPDATE ON public.gmail_tokens
  FOR EACH ROW EXECUTE FUNCTION public.update_gmail_tokens_updated_at();
