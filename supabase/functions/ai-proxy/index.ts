import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  // Defense-in-depth: verify a Bearer JWT is present even though Supabase
  // gateway already validates it. Rejects anonymous / keyless calls explicitly
  // rather than relying solely on the gateway configuration.
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return Response.json({ error: 'Unauthorized' }, { status: 401, headers: CORS });
  }

  try {
    const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
    if (!apiKey) return Response.json({ error: 'ANTHROPIC_API_KEY not configured' }, { status: 500, headers: CORS });

    const { messages, max_tokens = 400, system } = await req.json();

    const body: Record<string, unknown> = {
      model: 'claude-haiku-4-5-20251001',
      max_tokens,
      messages,
    };
    if (system) body.system = system;

    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    const data = await res.json();
    return Response.json(data, { headers: CORS });
  } catch (e) {
    return Response.json({ error: { message: e.message } }, { status: 500, headers: CORS });
  }
});

