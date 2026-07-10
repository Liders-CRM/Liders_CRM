import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const ALLOWED_ORIGINS = [
  'https://plto.app',
  'https://www.plto.app',
  'http://localhost:8080',
  'http://127.0.0.1:8080',
];

// תיבת המייל המחוברת משותפת לכל החברה — גישה מוגבלת לאדמינים בלבד,
// לא per-tenant כמו שאר ה-RPCs/functions.
const ADMIN_EMAILS = ['liders.crm@gmail.com', 'elgrablidudu@gmail.com'];

function corsHeaders(origin: string | null) {
  const allowed =
    origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin':  allowed,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
}

const NOISE_SENDERS = [
  'noreply@', 'no-reply@', 'mailer-daemon@', 'postmaster@',
  'notifications@github.com', 'notifications@supabase.io',
  'donotreply@', 'automated@', 'bounce@',
];

const NOISE_SUBJECTS = [
  'lead updated', 'form submission', 'test notification',
  'hook triggered', 'webhook received', 'make scenario',
  'supabase alert', 'github actions',
];

function isNoise(from: string, subject: string): boolean {
  const f = from.toLowerCase();
  const s = subject.toLowerCase();
  return NOISE_SENDERS.some((n) => f.includes(n)) ||
    NOISE_SUBJECTS.some((n) => s.includes(n));
}

async function getAccessToken(
  supabase: ReturnType<typeof createClient>,
  clientId: string,
  clientSecret: string,
): Promise<string> {
  const { data: row, error } = await supabase
    .from('gmail_tokens')
    .select('access_token, refresh_token, expires_at')
    .eq('account', 'liders.crm@gmail.com')
    .single();

  if (error || !row) throw new Error('gmail_tokens: לא נמצא token — יש לבצע OAuth תחילה');

  const expiresAt = row.expires_at ? new Date(row.expires_at).getTime() : 0;
  const fiveMin   = 5 * 60 * 1000;

  if (row.access_token && expiresAt - Date.now() > fiveMin) {
    return row.access_token;
  }

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method:  'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:    new URLSearchParams({
      client_id:     clientId,
      client_secret: clientSecret,
      refresh_token: row.refresh_token,
      grant_type:    'refresh_token',
    }),
  });

  const tokens = await res.json() as {
    access_token?: string;
    expires_in?: number;
    error?: string;
  };

  if (!tokens.access_token) throw new Error(`refresh failed: ${tokens.error}`);

  const newExpiry = new Date(Date.now() + (tokens.expires_in ?? 3600) * 1000).toISOString();

  await supabase.from('gmail_tokens').update({
    access_token: tokens.access_token,
    expires_at:   newExpiry,
  }).eq('account', 'liders.crm@gmail.com');

  return tokens.access_token;
}

async function gmailGet(token: string, path: string, params?: Record<string, string | string[]>) {
  const u = new URL(`https://gmail.googleapis.com/gmail/v1/users/me/${path}`);
  if (params) {
    Object.entries(params).forEach(([k, v]) => {
      if (Array.isArray(v)) v.forEach((val) => u.searchParams.append(k, val));
      else u.searchParams.set(k, v);
    });
  }
  const res = await fetch(u, { headers: { Authorization: `Bearer ${token}` } });
  return res.json();
}

async function gmailPost(token: string, path: string, body: unknown) {
  const res = await fetch(`https://gmail.googleapis.com/gmail/v1/users/me/${path}`, {
    method:  'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body:    JSON.stringify(body),
  });
  return res.json();
}

function encodeEmail(to: string, subject: string, body: string, replyToId?: string): string {
  const headers = [
    `To: ${to}`,
    `From: liders.crm@gmail.com`,
    `Subject: =?UTF-8?B?${btoa(unescape(encodeURIComponent(subject)))}?=`,
    'MIME-Version: 1.0',
    'Content-Type: text/html; charset=UTF-8',
    replyToId ? `In-Reply-To: ${replyToId}` : '',
  ].filter(Boolean).join('\r\n');

  const raw = `${headers}\r\n\r\n${body}`;
  return btoa(unescape(encodeURIComponent(raw)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get('origin');
  const cors   = corsHeaders(origin);

  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST')
    return new Response('Method not allowed', { status: 405, headers: cors });

  // ── 1. חובה: מזהה משתמש מחובר מאומת (לא anon key בלבד) ──────────────────
  const authHeader = req.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } },
    );
  }

  const supabaseUrl  = Deno.env.get('SUPABASE_URL') ?? '';
  const supabaseAnon = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  const authClient = createClient(supabaseUrl, supabaseAnon, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: authErr } = await authClient.auth.getUser();
  if (authErr || !user) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } },
    );
  }

  // ── 2. תיבת המייל היא משאב משותף של החברה — לא per-tenant — רק אדמין ────
  if (!ADMIN_EMAILS.includes((user.email ?? '').toLowerCase())) {
    return new Response(
      JSON.stringify({ error: 'Forbidden' }),
      { status: 403, headers: { ...cors, 'Content-Type': 'application/json' } },
    );
  }

  const clientId     = Deno.env.get('GMAIL_CLIENT_ID')     ?? '';
  const clientSecret = Deno.env.get('GMAIL_CLIENT_SECRET') ?? '';

  if (!clientId || !clientSecret) {
    return new Response(
      JSON.stringify({ error: 'GMAIL credentials not configured' }),
      { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } },
    );
  }

  const supabase = createClient(
    supabaseUrl,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: 'Invalid JSON' }),
      { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } },
    );
  }

  const action = body.action as string;

  let result: unknown;
  try {
    const token = await getAccessToken(supabase, clientId, clientSecret);

    switch (action) {

      case 'list': {
        const filter    = (body.filter as string) ?? 'important';
        const maxResults = Math.min((body.maxResults as number) ?? 20, 50);
        const query = filter === 'unread'
          ? 'is:unread'
          : filter === 'important'
          ? 'is:important OR is:starred'
          : 'in:inbox';

        const data = await gmailGet(token, 'threads', { q: query, maxResults: String(maxResults) });
        const threads = data.threads ?? [];

        const detailed = await Promise.all(
          threads.map(async (t: { id: string }) => {
            const thread = await gmailGet(token, `threads/${t.id}`, {
              format: 'metadata',
              metadataHeaders: ['From', 'Subject', 'Date'],
            });
            const msg = thread.messages?.[0];
            const headers = Object.fromEntries(
              (msg?.payload?.headers ?? []).map((h: { name: string; value: string }) => [h.name, h.value]),
            );
            const from    = headers['From']    ?? '';
            const subject = headers['Subject'] ?? '(אין נושא)';

            if (isNoise(from, subject)) return null;

            return {
              id:        t.id,
              messageId: msg?.id,
              from,
              subject,
              date:      headers['Date'] ?? '',
              snippet:   thread.messages?.[thread.messages.length - 1]?.snippet ?? '',
              unread:    (msg?.labelIds ?? []).includes('UNREAD'),
            };
          }),
        );

        result = { threads: detailed.filter(Boolean) };
        break;
      }

      case 'get': {
        const threadId = body.threadId as string;
        if (!threadId) throw new Error('threadId נדרש');
        const thread = await gmailGet(token, `threads/${threadId}`, { format: 'full' });

        const messages = (thread.messages ?? []).map((msg: Record<string, unknown>) => {
          const headers = Object.fromEntries(
            ((msg.payload as Record<string, unknown>)?.headers as Array<{name:string;value:string}> ?? [])
              .map((h) => [h.name, h.value]),
          );

          const getBody = (payload: Record<string, unknown>): string => {
            if (payload.mimeType === 'text/html' && payload.body) {
              return atob((payload.body as {data:string}).data?.replace(/-/g, '+').replace(/_/g, '/') ?? '');
            }
            if (payload.mimeType === 'text/plain' && payload.body) {
              const plain = atob((payload.body as {data:string}).data?.replace(/-/g, '+').replace(/_/g, '/') ?? '');
              return `<pre>${plain}</pre>`;
            }
            const parts = (payload.parts as Record<string, unknown>[]) ?? [];
            for (const p of parts) {
              const b = getBody(p); if (b) return b;
            }
            return '';
          };

          return {
            id:      msg.id,
            from:    headers['From']    ?? '',
            to:      headers['To']      ?? '',
            subject: headers['Subject'] ?? '',
            date:    headers['Date']    ?? '',
            body:    getBody(msg.payload as Record<string, unknown>),
            unread:  ((msg.labelIds as string[]) ?? []).includes('UNREAD'),
          };
        });

        if (messages.some((m: {unread:boolean}) => m.unread)) {
          await gmailPost(token, `threads/${threadId}/modify`,
            { removeLabelIds: ['UNREAD'] });
        }

        result = { thread: { id: thread.id, messages } };
        break;
      }

      case 'send': {
        const { to, subject, htmlBody, replyToId } = body as {
          to: string; subject: string; htmlBody: string; replyToId?: string;
        };
        if (!to || !subject || !htmlBody) throw new Error('to, subject, htmlBody נדרשים');

        const raw = encodeEmail(to, subject, htmlBody, replyToId);
        const sent = await gmailPost(token, 'messages/send', { raw,
          ...(replyToId ? { threadId: replyToId } : {}) });
        result = { sent: { id: sent.id } };
        break;
      }

      case 'label': {
        const { threadId, add = [], remove = [] } = body as {
          threadId: string; add?: string[]; remove?: string[];
        };
        if (!threadId) throw new Error('threadId נדרש');
        await gmailPost(token, `threads/${threadId}/modify`,
          { addLabelIds: add, removeLabelIds: remove });
        result = { ok: true };
        break;
      }

      case 'create_label': {
        const { name, color } = body as { name: string; color?: string };
        if (!name) throw new Error('name נדרש');
        const existing = await gmailGet(token, 'labels');
        const found = (existing.labels ?? []).find(
          (l: { name: string }) => l.name === name,
        );
        if (found) { result = { label: found }; break; }
        const payload: Record<string, unknown> = { name, labelListVisibility: 'labelShow',
          messageListVisibility: 'show' };
        if (color) payload.color = { backgroundColor: color, textColor: '#ffffff' };
        result = { label: await gmailPost(token, 'labels', payload) };
        break;
      }

      default:
        throw new Error(`action לא מוכר: ${action}`);
    }

  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } },
    );
  }

  return new Response(
    JSON.stringify(result),
    { headers: { ...cors, 'Content-Type': 'application/json' } },
  );
});
