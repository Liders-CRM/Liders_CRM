-- Migration 058: pre-render the digest ticket list as HTML in Postgres itself
-- (string_agg), instead of relying on Make.com iterator modules, so the Make
-- scenario side just drops one ready-made HTML block into the email body.

SELECT cron.unschedule('liders-support-daily-digest');

SELECT cron.schedule(
  'liders-support-daily-digest',
  '30 17 * * *',
  $cron$
  SELECT net.http_post(
    url := 'https://hook.eu1.make.com/f0nzngm6gdokri5naqu7enbay538ay8i',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := jsonb_build_object(
      'event', 'support.daily_digest',
      'since', (now() - interval '24 hours')::text,
      'total_tickets', (SELECT count(*) FROM public.get_support_digest(now() - interval '24 hours')),
      'needs_human_count', (SELECT count(*) FROM public.get_support_digest(now() - interval '24 hours') WHERE needs_human),
      'tickets_html', (
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
          '<p style="color:#9CA3AF;">אין פניות תמיכה ב-24 השעות האחרונות</p>'
        )
        FROM public.get_support_digest(now() - interval '24 hours')
      )
    )
  );
  $cron$
);
