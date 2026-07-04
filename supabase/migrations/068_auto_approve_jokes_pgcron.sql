-- Migration 068: replace daily Claude Code trigger with free pg_cron auto-approval
-- Runs at 07:00 UTC = 10:00 AM Israel summer (UTC+3)

-- Auto-approve function (SQL rules, no AI required)
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
    -- Skip: user already received an approval today
    SELECT COUNT(*) INTO v_daily_cnt
    FROM public.community_jokes
    WHERE submitted_by = v_joke.submitted_by
      AND status = 'approved'
      AND approved_at >= CURRENT_DATE;

    IF v_daily_cnt >= 1 THEN
      CONTINUE;
    END IF;

    -- Approve if content length is valid (same rules as submit_community_joke)
    IF length(trim(v_joke.joke_text)) BETWEEN 20 AND 1200 THEN
      UPDATE public.community_jokes
      SET status      = 'approved',
          approved_at = NOW(),
          xp_awarded  = false
      WHERE id = v_joke.id
        AND status = 'pending';  -- safety re-check
    END IF;
  END LOOP;
END;
$$;

-- Schedule: every day at 07:00 UTC (10:00 AM Israel summer / 09:00 AM winter)
-- Remove existing schedule first (idempotent)
SELECT cron.unschedule('auto-approve-daily-jokes') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'auto-approve-daily-jokes'
);

SELECT cron.schedule(
  'auto-approve-daily-jokes',
  '0 7 * * *',
  $$SELECT public.auto_approve_daily_jokes()$$
);
