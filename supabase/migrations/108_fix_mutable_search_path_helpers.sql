-- Migration 108: Pin search_path on 6 helper functions flagged by Supabase's
-- security advisor as "function_search_path_mutable".
--
-- Without a pinned search_path, a function resolves unqualified object names
-- (and, for plpgsql, the resolution of other functions/operators it calls) at
-- call time using the caller's current search_path. Since none of these
-- functions currently write to or read from any user-writable schema, there
-- is no known exploitable path today — but the fix is free and closes the
-- theoretical door (a future search_path hijack via a role with schema-
-- creation rights) with zero behavior change. Same fix pattern already
-- applied to _plan_price_config (migration 103) and used throughout the
-- SECURITY DEFINER RPCs (`SET search_path TO 'public'`).
--
-- Bodies are byte-for-byte identical to what's live today (pulled via
-- pg_get_functiondef) — this migration only adds the SET clause.

CREATE OR REPLACE FUNCTION public._seat_config(p_plan text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT (
    '{
      "trial":     {"included": 1,  "max": 1,  "price": 0},
      "basic":     {"included": 1,  "max": 1,  "price": 0},
      "pro":       {"included": 3,  "max": 7,  "price": 40},
      "premium":   {"included": 10, "max": 25, "price": 40},
      "lifetime":  {"included": 10, "max": 25, "price": 40},
      "cancelled": {"included": 0,  "max": 0,  "price": 0}
    }'::jsonb -> p_plan
  );
$function$;

CREATE OR REPLACE FUNCTION public._commission_label_he(p_type text, p_value numeric)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE p_type
    WHEN 'percent' THEN trim(trailing '.' from trim(trailing '0' from round(p_value,2)::text)) || '% מהתמורה בעסקה'
    WHEN 'fixed'   THEN '₪' || trim(trailing '.' from trim(trailing '0' from round(p_value,2)::text)) || ' (סכום קבוע)'
    ELSE 'ללא עמלה'
  END;
$function$;

CREATE OR REPLACE FUNCTION public._is_disposable_email(p_email text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT lower(split_part(p_email, '@', 2)) = ANY (ARRAY[
    'mailinator.com','guerrillamail.com','guerrillamail.net','guerrillamail.org',
    'guerrillamail.biz','guerrillamailblock.com','sharklasers.com','grr.la',
    '10minutemail.com','10minutemail.net','10minemail.com','20minutemail.com',
    'tempmail.com','temp-mail.org','temp-mail.io','tempmail.net','tempmailo.com',
    'tempinbox.com','fakeinbox.com','fakemailgenerator.com','fakemail.net',
    'yopmail.com','yopmail.net','yopmail.fr','cool.fr.nf','jetable.fr.nf',
    'trashmail.com','trashmail.net','trashmail.me','trash-mail.com','trashmailer.com',
    'dispostable.com','maildrop.cc','mailnesia.com','mailcatch.com','mail-temporaire.fr',
    'getnada.com','nada.email','mohmal.com','emailondeck.com','moakt.com','moakt.cc',
    'inboxkitten.com','spam4.me','throwawaymail.com','mytemp.email','tempr.email',
    'discard.email','discardmail.com','mintemail.com','mvrht.net','anonbox.net',
    'burnermail.io','emailfake.com','crazymailing.com','tempmailaddress.com',
    'mail-temp.com','one-time.email','harakirimail.com','shieldedmail.com',
    'spamgourmet.com','spambox.us','tmpmail.org','tmpeml.com','tmail.ws'
  ]);
$function$;

CREATE OR REPLACE FUNCTION public._vertical_label_he(p_vertical text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT CASE p_vertical
    WHEN 'realestate'        THEN 'סוכן נדל"ן'
    WHEN 'realestate_lawyer' THEN 'עו"ד נדל"ן'
    WHEN 'interior'          THEN 'מעצב פנים'
    WHEN 'other'             THEN 'בעל מקצוע'
    ELSE 'בעל מקצוע'
  END;
$function$;

CREATE OR REPLACE FUNCTION public._build_referral_agreement_text(p_referrer_name text, p_to_vertical text, p_lead_first_name text, p_commission_type text, p_commission_value numeric, p_to_profession text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT 'הסכם עמלת הפניה — PLTO' || E'\n'
      || '════════════════════════════' || E'\n\n'
      || 'המפנה: ' || p_referrer_name || E'\n'
      || 'המקבל: ' || coalesce(nullif(trim(p_to_profession),''), _vertical_label_he(p_to_vertical))
                   || ' (שמו המלא יופיע בחתימה)' || E'\n'
      || 'הליד המועבר: ' || coalesce(nullif(p_lead_first_name,''), 'ליד') || E'\n'
      || 'תאריך: ' || to_char(now() AT TIME ZONE 'Asia/Jerusalem', 'DD/MM/YYYY') || E'\n\n'
      || '1. המפנה מעביר למקבל ליד לטיפול מקצועי בתחומו של המקבל.' || E'\n'
      || '2. פרטי הליד המלאים ייחשפו למקבל רק לאחר חתימתו על הסכם זה.' || E'\n'
      || '3. אם תיסגר עסקה שמקורה בליד זה, ישלם המקבל למפנה עמלת הפניה בשיעור: '
      || _commission_label_he(p_commission_type, p_commission_value) || '.' || E'\n'
      || '4. התשלום יבוצע בתוך 30 יום ממועד קבלת התמורה בעסקה, כנגד חשבונית כדין.' || E'\n'
      || '5. המקבל מתחייב לטפל בליד במקצועיות ולעדכן את המפנה על סגירת עסקה שמקורה בהפניה.' || E'\n'
      || '6. הסכם זה תקף להפניה זו בלבד ואינו יוצר יחסי שותפות או שליחות בין הצדדים.' || E'\n'
      || '7. PLTO היא פלטפורמה טכנולוגית בלבד ואינה צד להסכם, אינה גובה את העמלה ואינה אחראית לאכיפתו.' || E'\n'
      || '8. החתימה הדיגיטלית שלהלן, בצירוף תיעוד מועד החתימה וזהות החותם, מהווה אישור הדדי מחייב בין הצדדים.' || E'\n';
$function$;

CREATE OR REPLACE FUNCTION public.update_gmail_tokens_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$function$;
