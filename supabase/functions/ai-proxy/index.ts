import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Only allow production domain + local dev
const ALLOWED_ORIGINS = [
  'https://plto.app',
  'https://www.plto.app',
  'https://liders-crm.com',
  'https://www.liders-crm.com',
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

const ALLOWED_MODELS = [
  'claude-haiku-4-5-20251001',
  'claude-sonnet-4-6',
];

const ALLOWED_TYPES = ['general', 'marketing', 'quicklog', 'support', 'motivation'];
const DEFAULT_MODEL = 'claude-haiku-4-5-20251001';

// Hard caps — client cannot exceed these
const MAX_TOKENS_CAP   = 1000;
const MAX_SYSTEM_LEN   = 2000; // chars
const MAX_CONTENT_LEN  = 4000; // chars per message
const MAX_MESSAGES     = 6;

serve(async (req) => {
  const origin = req.headers.get('origin');
  const cors = corsHeaders(origin);

  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  try {
    // ── 1. Verify caller is an authenticated Supabase user ──────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return Response.json({ error: 'Unauthorized' }, { status: 401, headers: cors });
    }

    const supabaseUrl  = Deno.env.get('SUPABASE_URL');
    const supabaseAnon = Deno.env.get('SUPABASE_ANON_KEY');
    if (!supabaseUrl || !supabaseAnon) {
      return Response.json({ error: 'Server misconfigured' }, { status: 500, headers: cors });
    }

    const sbClient = createClient(supabaseUrl, supabaseAnon, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authErr } = await sbClient.auth.getUser();
    if (authErr || !user) {
      return Response.json({ error: 'Unauthorized' }, { status: 401, headers: cors });
    }

    // ── 2. Read and validate request body ───────────────────────────────
    const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
    if (!apiKey) {
      return Response.json({ error: 'ANTHROPIC_API_KEY not configured' }, { status: 500, headers: cors });
    }

    const body = await req.json();
    const { messages, system, model: requestedModel, type: rawType } = body;

    // ── 3. Server-side quota enforcement ────────────────────────────────
    const aiType = ALLOWED_TYPES.includes(rawType) ? rawType : 'general';
    const { data: quota, error: quotaErr } = await sbClient.rpc(
      'check_and_increment_ai_usage',
      { p_type: aiType }
    );
    if (quotaErr || !quota?.allowed) {
      return Response.json(
        {
          error: 'quota_exceeded',
          reason: quota?.reason ?? 'daily_limit',
          plan:  quota?.plan  ?? 'unknown',
          used:  quota?.used  ?? 0,
          limit: quota?.limit ?? 0,
          retry_after_seconds: quota?.retry_after_seconds ?? null,
        },
        { status: 429, headers: cors }
      );
    }

    // ── 4. Validate and sanitize messages ───────────────────────────────
    // Cap max_tokens server-side regardless of client value
    const max_tokens = Math.min(Number(body.max_tokens) || 400, MAX_TOKENS_CAP);

    if (!Array.isArray(messages) || messages.length === 0) {
      return Response.json({ error: 'messages required' }, { status: 400, headers: cors });
    }
    if (messages.length > MAX_MESSAGES) {
      return Response.json({ error: 'Too many messages' }, { status: 400, headers: cors });
    }

    const safeMessages = messages.map((m: { role: string; content: string }) => ({
      role: m.role === 'assistant' ? 'assistant' : 'user',
      content: (typeof m.content === 'string' ? m.content : '').slice(0, MAX_CONTENT_LEN),
    }));

    const safeSystem = typeof system === 'string' ? system.slice(0, MAX_SYSTEM_LEN) : undefined;
    const model = ALLOWED_MODELS.includes(requestedModel) ? requestedModel : DEFAULT_MODEL;

    // ── 5. Forward to Anthropic ─────────────────────────────────────────
    const reqBody: Record<string, unknown> = {
      model,
      max_tokens,
      messages: safeMessages,
    };
    if (safeSystem) reqBody.system = safeSystem;

    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify(reqBody),
    });

    const data = await res.json();
    return Response.json(data, { headers: cors });
  } catch (e) {
    return Response.json({ error: { message: (e as Error).message } }, { status: 500, headers: cors });
  }
});
