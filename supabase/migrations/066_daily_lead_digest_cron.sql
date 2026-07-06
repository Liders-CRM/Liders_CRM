-- Migration 066: daily lead digest cron job
-- רץ כל יום 15:00 UTC = 18:00 ישראל (קיץ UTC+3).
-- שולף את כל הלידים שנוצרו היום ושולח דוח מסודר ל-Make.com webhook,
-- שם route חדש lead.daily_digest שולח מייל מסכם אחד לאדמין.

CREATE OR REPLACE FUNCTION public.send_daily_lead_digest()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
DECLARE
  v_count        INT;
  v_tenant_count INT;
  v_leads_html   TEXT;
  v_today        TEXT;
  v_day_start    TIMESTAMPTZ;
BEGIN
  v_today     := to_char(now() AT TIME ZONE 'Asia/Jerusalem', 'DD/MM/YYYY');
  v_day_start := date_trunc('day', now() AT TIME ZONE 'Asia/Jerusalem') AT TIME ZONE 'Asia/Jerusalem';

  SELECT
    COUNT(*)::INT,
    COUNT(DISTINCT l.tenant_id)::INT,
    COALESCE(
      string_agg(
        '<tr>' ||
        '<td style="padding:10px 14px;border-bottom:1px solid #E2E8F0;font-weight:600;">' ||
          replace(replace(replace(COALESCE(l.name, '—'), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') ||
        '</td>' ||
        '<td style="padding:10px 14px;border-bottom:1px solid #E2E8F0;direction:ltr;">' ||
          COALESCE(l.phone, '—') ||
        '</td>' ||
        '<td style="padding:10px 14px;border-bottom:1px solid #E2E8F0;">' ||
          CASE COALESCE(t.industry, '')
            WHEN 'realestate'        THEN 'סוכן נדל"ן'
            WHEN 'realestate_lawyer' THEN 'עו"ד נדל"ן'
            WHEN 'interior'          THEN 'עיצוב פנים'
            ELSE 'אחר'
          END ||
        '</td>' ||
        '<td style="padding:10px 14px;border-bottom:1px solid #E2E8F0;">' ||
          replace(replace(replace(COALESCE(t.name, '—'), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') ||
        '</td>' ||
        '</tr>',
        '' ORDER BY l.created_at
      ),
      ''
    )
  INTO v_count, v_tenant_count, v_leads_html
  FROM leads l
  LEFT JOIN tenants t ON t.id = l.tenant_id
  WHERE l.created_at >= v_day_start
    AND l.created_at < now();

  -- לא שולח מייל ריק אם לא נוצרו לידים היום
  IF v_count > 0 THEN
    PERFORM net.http_post(
      url     := 'https://hook.eu1.make.com/f0nzngm6gdokri5naqu7enbay538ay8i',
      headers := '{"Content-Type":"application/json"}'::jsonb,
      body    := json_build_object(
        'event',        'lead.daily_digest',
        'date',         v_today,
        'count',        v_count,
        'tenant_count', v_tenant_count,
        'leads_html',   v_leads_html
      )::text
    );
  END IF;
END;
$func$;

GRANT EXECUTE ON FUNCTION public.send_daily_lead_digest() TO postgres;

-- הסרת עבודה קיימת אם יש (idempotent)
DO $$ BEGIN
  PERFORM cron.unschedule('liders-leads-daily-digest');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 15:00 UTC = 18:00 שעון ישראל (קיץ UTC+3)
SELECT cron.schedule(
  'liders-leads-daily-digest',
  '0 15 * * *',
  $$SELECT public.send_daily_lead_digest()$$
);
