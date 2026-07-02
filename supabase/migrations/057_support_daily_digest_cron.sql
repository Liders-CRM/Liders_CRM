-- Migration 057: daily support-digest cron job
-- Uses pg_cron + pg_net (both native Postgres, no external secrets needed) to push
-- a once-a-day summary of the last 24h of support activity straight to the existing
-- Make.com webhook, reusing the already-authorized Gmail connection there.

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

GRANT EXECUTE ON FUNCTION public.get_support_digest(timestamptz) TO postgres;

SELECT cron.schedule(
  'liders-support-daily-digest',
  '30 17 * * *',  -- 17:30 UTC ≈ evening in Israel (shifts ±1h across DST, fixed UTC cron)
  $cron$
  SELECT net.http_post(
    url := 'https://hook.eu1.make.com/f0nzngm6gdokri5naqu7enbay538ay8i',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := jsonb_build_object(
      'event', 'support.daily_digest',
      'since', (now() - interval '24 hours')::text,
      'total_tickets', (SELECT count(*) FROM public.get_support_digest(now() - interval '24 hours')),
      'needs_human_count', (SELECT count(*) FROM public.get_support_digest(now() - interval '24 hours') WHERE needs_human),
      'tickets', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
                    'tenant_name', tenant_name,
                    'agent_name', agent_name,
                    'status', status,
                    'needs_human', needs_human,
                    'message', left(message, 200),
                    'message_count', message_count
                  )), '[]'::jsonb) FROM public.get_support_digest(now() - interval '24 hours'))
    )
  );
  $cron$
);
