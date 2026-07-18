import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Only allow production domain + local dev
const ALLOWED_ORIGINS = [
  'https://plto.app',
  'https://www.plto.app',
  'http://localhost:8080',
  'http://127.0.0.1:8080',
];

function corsHeaders(origin: string | null) {
  const allowed = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
}

const MAX_MESSAGE_LEN = 2000;

Deno.serve(async (req: Request) => {
  const origin = req.headers.get('origin');
  const cors = corsHeaders(origin);

  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  try {
    // ── Verify caller is an authenticated Supabase user ──────────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    const supabaseUrl  = Deno.env.get('SUPABASE_URL');
    const supabaseAnon = Deno.env.get('SUPABASE_ANON_KEY');
    if (!supabaseUrl || !supabaseAnon) {
      return new Response(JSON.stringify({ error: 'Server misconfigured' }), {
        status: 500, headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    const sbClient = createClient(supabaseUrl, supabaseAnon, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authErr } = await sbClient.auth.getUser();
    if (authErr || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    const ACCOUNT_SID = Deno.env.get('TWILIO_ACCOUNT_SID');
    const AUTH_TOKEN  = Deno.env.get('TWILIO_AUTH_TOKEN');
    const FROM        = Deno.env.get('TWILIO_WHATSAPP_FROM') ?? '+14155238886';

    if (!ACCOUNT_SID || !AUTH_TOKEN) {
      return new Response(
        JSON.stringify({ error: 'Twilio credentials not configured' }),
        { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } }
      );
    }

    const { to, message } = await req.json();
    if (!to || typeof to !== 'string' || !message || typeof message !== 'string') {
      return new Response(
        JSON.stringify({ error: 'to and message are required' }),
        { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } }
      );
    }

    // Tenant isolation: verify the destination phone belongs to a lead in this user's tenant,
    // OR matches the tenant's own configured self-notification number (Settings -> WhatsApp
    // Business number). The self-notify exception was added 18/7/2026: Twilio.notifyNewLead/
    // notifyStageChanged/notifyTaskDue/notifyColdLeads/test all send to the tenant's own number
    // to alert the agent about their own CRM activity, not to a lead - without this exception
    // every one of those calls was silently rejected as phone_not_in_leads, so the feature never
    // actually delivered a message. Safe because the number came from the tenant itself via
    // update_tenant_integrations(), not from attacker-controlled input.
    // RLS on the leads/tenants tables automatically scopes both checks to the authenticated user's tenant.
    const rawPhone = to.replace(/^whatsapp:/, '').trim();
    if (!/^\+?[0-9]{7,15}$/.test(rawPhone)) {
      return new Response(
        JSON.stringify({ error: 'invalid phone format' }),
        { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } },
      );
    }

    const toIntlDigits = (s: string) => {
      const d = (s || '').replace(/\D/g, '');
      return d.startsWith('0') ? '972' + d.slice(1) : d;
    };

    let selfNotifyAuthorized = false;
    const { data: tenantId } = await sbClient.rpc('get_my_tenant_id');
    if (tenantId) {
      const { data: tenantRow } = await sbClient
        .from('tenants')
        .select('whatsapp_number')
        .eq('id', tenantId)
        .maybeSingle();
      const tenantDigits = toIntlDigits(tenantRow?.whatsapp_number ?? '');
      if (tenantDigits && tenantDigits === toIntlDigits(rawPhone)) selfNotifyAuthorized = true;
    }

    if (!selfNotifyAuthorized) {
      const altPhone = rawPhone.startsWith('+972')
        ? '0' + rawPhone.slice(4)
        : rawPhone.startsWith('0')
          ? '+972' + rawPhone.slice(1)
          : null;
      const candidates = altPhone ? [rawPhone, altPhone] : [rawPhone];
      const { data: leadCheck } = await sbClient
        .from('leads')
        .select('id')
        .in('phone', candidates)
        .limit(1)
        .maybeSingle();
      if (!leadCheck) {
        return new Response(
          JSON.stringify({ error: 'phone_not_in_leads' }),
          { status: 403, headers: { ...cors, 'Content-Type': 'application/json' } },
        );
      }
    }

    const safeMessage = message.slice(0, MAX_MESSAGE_LEN);

    // Normalise WhatsApp prefix
    const toFmt   = to.startsWith('whatsapp:')   ? to   : `whatsapp:${to}`;
    const fromFmt = FROM.startsWith('whatsapp:') ? FROM : `whatsapp:${FROM}`;

    const body = new URLSearchParams({
      From: fromFmt,
      To:   toFmt,
      Body: safeMessage,
    });

    const res = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${ACCOUNT_SID}/Messages.json`,
      {
        method:  'POST',
        headers: {
          Authorization:  `Basic ${btoa(`${ACCOUNT_SID}:${AUTH_TOKEN}`)}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body.toString(),
      }
    );

    const data = await res.json();

    if (!res.ok) {
      return new Response(
        JSON.stringify({ error: data.message ?? 'Twilio error', code: data.code }),
        { status: res.status, headers: { ...cors, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, sid: data.sid }),
      { headers: { ...cors, 'Content-Type': 'application/json' } }
    );

  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } }
    );
  }
});
