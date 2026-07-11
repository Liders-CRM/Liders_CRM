-- Migration 080: skip support digest email when there are 0 tickets in last 24h
--
-- Previously the cron ran inline SQL that always called net.http_post regardless
-- of ticket count, causing a daily "0 פניות" email. Now a function handles the
-- conditional: if nothing happened, return early and send nothing.

CREATE OR REPLACE FUNCTION public.send_support_daily_digest()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total  bigint;
  v_needs  bigint;
  v_html   text;
BEGIN
  SELECT count(*) INTO v_total
  FROM public.get_support_digest(now() - interval '24 hours');

  -- No tickets — skip entirely, no email sent
  IF v_total = 0 THEN RETURN; END IF;

  SELECT count(*) INTO v_needs
  FROM public.get_support_digest(now() - interval '24 hours')
  WHERE needs_human;

  SELECT COALESCE(
    string_agg(
      format(
        '<div style="background:#fff;border:1px solid %s;border-radius:8px;padding:10px 14px;margin-bottom:8px;"><strong>%s</strong> (%s) — %s<br><span style="color:#6B7280;font-size:13px;">%s</span></div>',
        CASE WHEN needs_human THEN '#FCA5A5' ELSE '#E2E8F0' END,
        coalesce(tenant_name, '—'),
        coalesce(agent_name, '—'),
        CASE WHEN needs_human THEN '🆘 דורש התערבות' ELSE status END,
        left(coalesce(message, ''), 160)
      ),
      ''
    ),
    ''
  ) INTO v_html
  FROM public.get_support_digest(now() - interval '24 hours');

  PERFORM net.http_post(
    url     := 'https://hook.eu1.make.com/f0nzngm6gdokri5naqu7enbay538ay8i',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body    := jsonb_build_object(
      'event',             'support.daily_digest',
      'since',             (now() - interval '24 hours')::text,
      'total_tickets',     v_total,
      'needs_human_count', v_needs,
      'tickets_html',      v_html
    )
  );
END;
$$;

-- Only postgres (pg_cron) may call this — not anon/authenticated (pattern from 077)
REVOKE EXECUTE ON FUNCTION public.send_support_daily_digest() FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.send_support_daily_digest() TO postgres;

-- Swap the cron: replace inline SQL blob with a simple function call
DO $$ BEGIN PERFORM cron.unschedule('plto-support-daily-digest'); EXCEPTION WHEN OTHERS THEN NULL; END $$;

SELECT cron.schedule(
  'plto-support-daily-digest',
  '30 17 * * *',
  $$SELECT public.send_support_daily_digest()$$
);
