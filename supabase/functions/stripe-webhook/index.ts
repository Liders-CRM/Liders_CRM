import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const STRIPE_WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? '';
const SUPABASE_URL           = Deno.env.get('SUPABASE_URL')           ?? '';
const SUPABASE_SERVICE_KEY   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

// Map Stripe metadata plan values to DB plan values
const VALID_PLANS = new Set(['basic', 'pro', 'premium']);

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const body      = await req.text();
  const signature = req.headers.get('stripe-signature') ?? '';

  // Verify Stripe signature using Web Crypto (no Node crypto available in Deno)
  const valid = await verifyStripeSignature(body, signature, STRIPE_WEBHOOK_SECRET);
  if (!valid) {
    return new Response('Invalid signature', { status: 401 });
  }

  const event = JSON.parse(body);
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  try {
    if (event.type === 'checkout.session.completed') {
      const session = event.data.object;
      const tenantId = session.client_reference_id;
      const plan     = session.metadata?.plan;

      if (!tenantId) {
        console.error('Missing client_reference_id in session', session.id);
        return new Response('Missing tenant ID', { status: 400 });
      }
      if (!plan || !VALID_PLANS.has(plan)) {
        console.error('Missing or invalid plan in metadata', session.id, plan);
        return new Response('Missing plan metadata', { status: 400 });
      }

      const { error } = await supabase
        .from('tenants')
        .update({
          plan,
          plan_expires_at: null, // subscriptions managed by Stripe
          billing_email: session.customer_details?.email ?? null,
        })
        .eq('id', tenantId);

      if (error) throw error;
      console.log(`Tenant ${tenantId} upgraded to ${plan}`);
    }

    if (event.type === 'customer.subscription.deleted') {
      const subscription = event.data.object;
      const customerId   = subscription.customer;

      // Find tenant by billing_email via customer lookup
      // (simpler: store customer_id on tenant — future improvement)
      // For now: downgrade all tenants with this customer's email
      const { error } = await supabase
        .from('tenants')
        .update({ plan: 'trial' })
        .eq('stripe_customer_id', customerId);

      if (error) console.warn('subscription.deleted update:', error.message);
      console.log(`Customer ${customerId} subscription cancelled — downgraded to trial`);
    }
  } catch (err) {
    console.error('Webhook handler error:', err);
    return new Response('Internal error', { status: 500 });
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});

async function verifyStripeSignature(
  payload: string,
  header: string,
  secret: string,
): Promise<boolean> {
  try {
    const parts     = Object.fromEntries(header.split(',').map(p => p.split('=')));
    const timestamp = parts['t'];
    const v1        = parts['v1'];
    if (!timestamp || !v1) return false;

    const signedPayload = `${timestamp}.${payload}`;
    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign'],
    );
    const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(signedPayload));
    const computed = Array.from(new Uint8Array(sig))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    // constant-time compare to prevent timing side-channel attacks
    const a = new TextEncoder().encode(computed);
    const b = new TextEncoder().encode(v1);
    if (a.length !== b.length) return false;
    let diff = 0;
    for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
    return diff === 0;
  } catch {
    return false;
  }
}
