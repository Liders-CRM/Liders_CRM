-- Migration 087: fix verify_cron_report_secret() — the current_role check inside
-- a SECURITY DEFINER function reflects the function OWNER (postgres), not the
-- actual caller, so restricting to current_role='service_role' only always
-- failed (every call, including legitimate ones from the Edge Function).
--
-- The real access boundary in this codebase is the GRANT list (confirmed by
-- testing: `anon` gets "permission denied for function" — blocked before the
-- function body even runs — while `service_role`/`postgres` reach the body).
-- The internal current_role check is effectively decorative once GRANTs are
-- correct, but kept here in the same style as every other admin RPC
-- (current_role NOT IN ('postgres','service_role')) for consistency — not for
-- extra protection, since GRANT EXECUTE below is scoped to service_role only.

CREATE OR REPLACE FUNCTION public.verify_cron_report_secret(p_secret TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF current_role NOT IN ('postgres', 'service_role') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM vault.decrypted_secrets
    WHERE name = 'cro_report_internal_secret' AND decrypted_secret = p_secret
  );
END;
$$;

-- הרשאה נשארת מוגבלת ל-service_role בלבד — זו ההגנה האמיתית, לא ה-IF למעלה.
GRANT EXECUTE ON FUNCTION public.verify_cron_report_secret(TEXT) TO service_role;
REVOKE EXECUTE ON FUNCTION public.verify_cron_report_secret(TEXT) FROM PUBLIC, anon, authenticated;
