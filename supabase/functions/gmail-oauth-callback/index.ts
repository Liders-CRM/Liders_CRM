import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const REDIRECT_URI =
  'https://scyfywvzoogfrlalgftv.supabase.co/functions/v1/gmail-oauth-callback';

const SCOPES = [
  'https://www.googleapis.com/auth/gmail.readonly',
  'https://www.googleapis.com/auth/gmail.send',
  'https://www.googleapis.com/auth/gmail.labels',
  'https://www.googleapis.com/auth/gmail.modify',
].join(' ');

function html(body: string, status = 200) {
  return new Response(
    `<!DOCTYPE html><html dir="rtl" lang="he">
<head><meta charset="utf-8"><title>PLTO — Gmail</title>
<style>body{font-family:sans-serif;padding:60px;text-align:center;direction:rtl}</style>
</head><body>${body}</body></html>`,
    { status, headers: { 'Content-Type': 'text/html; charset=utf-8' } },
  );
}

Deno.serve(async (req: Request) => {
  const url  = new URL(req.url);
  const code  = url.searchParams.get('code');
  const error = url.searchParams.get('error');

  const clientId     = Deno.env.get('GMAIL_CLIENT_ID')     ?? '';
  const clientSecret = Deno.env.get('GMAIL_CLIENT_SECRET') ?? '';

  if (!clientId || !clientSecret) {
    return html('<h1>⚠️ GMAIL_CLIENT_ID / GMAIL_CLIENT_SECRET לא הוגדרו</h1>', 500);
  }

  if (error) {
    return html(`<h1>❌ שגיאת Google: ${error}</h1><p>נסה שוב מ-PLTO Admin.</p>`, 400);
  }

  if (!code) {
    const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
    authUrl.searchParams.set('client_id',     clientId);
    authUrl.searchParams.set('redirect_uri',  REDIRECT_URI);
    authUrl.searchParams.set('response_type', 'code');
    authUrl.searchParams.set('scope',         SCOPES);
    authUrl.searchParams.set('access_type',   'offline');
    authUrl.searchParams.set('prompt',        'consent');
    authUrl.searchParams.set('login_hint',    'liders.crm@gmail.com');
    return Response.redirect(authUrl.toString(), 302);
  }

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method:  'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:    new URLSearchParams({
      code,
      client_id:     clientId,
      client_secret: clientSecret,
      redirect_uri:  REDIRECT_URI,
      grant_type:    'authorization_code',
    }),
  });

  const tokens = await tokenRes.json() as {
    refresh_token?: string;
    access_token?: string;
    expires_in?: number;
    error?: string;
    error_description?: string;
  };

  if (tokens.error || !tokens.refresh_token) {
    return html(
      `<h1>❌ שגיאה בקבלת Token</h1><p>${tokens.error_description ?? tokens.error ?? 'חסר refresh_token'}</p>`,
      400,
    );
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );

  const expiresAt = new Date(Date.now() + (tokens.expires_in ?? 3600) * 1000).toISOString();

  const { error: dbErr } = await supabase.from('gmail_tokens').upsert(
    {
      account:       'liders.crm@gmail.com',
      refresh_token: tokens.refresh_token,
      access_token:  tokens.access_token ?? null,
      expires_at:    expiresAt,
    },
    { onConflict: 'account' },
  );

  if (dbErr) {
    return html(`<h1>❌ שגיאת DB</h1><p>${dbErr.message}</p>`, 500);
  }

  return html(`
    <h1>✅ החיבור הושלם בהצלחה!</h1>
    <p>המייל <strong>liders.crm@gmail.com</strong> מחובר למערכת PLTO.</p>
    <p style="color:#64748b;font-size:14px">אפשר לסגור את החלון הזה.</p>
  `);
});
