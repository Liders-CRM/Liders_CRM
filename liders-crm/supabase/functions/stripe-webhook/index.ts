import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const STRIPE_WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? '';
const SUPABASE_URL           = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_KEY   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

// Verify Stripe signature — constant-time comparison + replay-attack protection
async function verifyStripeSignature(payload: string, sig: string, secret: string): Promise<boolean> {
  const parts   = sig.split(',').reduce((acc: Record<string, string>, p) => {
    const [k, v] = p.split('='); acc[k] = v; return acc;
  }, {});
  const ts = parts['t'];
  const v1 = parts['v1'];
  if (!ts || !v1) return false;

  // Replay-attack protection: reject events older than 5 minutes
  if (Math.abs(Date.now() / 1000 - parseInt(ts, 10)) > 300) return false;

  const signed  = `${ts}.${payload}`;
  const key     = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sigBuf  = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(signed));
  const computed = Array.from(new Uint8Array(sigBuf)).map(b => b.toString(16).padStart(2, '0')).join('');

  // Constant-time comparison — prevents timing oracle attacks
  const a = new TextEncoder().encode(computed);
  const b = new TextEncoder().encode(v1);
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

// Plan mapping from Stripe Price ID → our plan name
// Fill these in after creating products in Stripe Dashboard:
const PRICE_TO_PLAN: Record<string, string> = {
  'REPLACE_PRICE_ID_BASIC':   'basic',
  'REPLACE_PRICE_ID_PRO':     'pro',
  'REPLACE_PRICE_ID_PREMIUM': 'premium',
};

serve(async (req: Request) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  const payload = await req.text();
  const sig     = req.headers.get('stripe-signature') ?? '';

  // Fail closed: refuse ALL requests if the webhook secret is not configured.
  // An empty/missing secret means ANY HTTP POST can forge billing events.
  if (!STRIPE_WEBHOOK_SECRET) {
    console.error('stripe-webhook: STRIPE_WEBHOOK_SECRET is not set — refusing request');
    return new Response('Webhook secret not configured', { status: 500 });
  }
  const valid = await verifyStripeSignature(payload, sig, STRIPE_WEBHOOK_SECRET);
  if (!valid) return new Response('Invalid signature', { status: 400 });

  const event = JSON.parse(payload);
  const sb    = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  if (event.type === 'checkout.session.completed') {
    const session       = event.data.object;
    const claimedId     = session.client_reference_id as string | null;
    const customerEmail = (session.customer_email as string | null)?.toLowerCase().trim() ?? null;
    const customerId    = session.customer as string | null;
    const subId         = session.subscription as string | null;
    const priceId       = session.line_items?.data?.[0]?.price?.id
                       || session.metadata?.price_id;

    if (!claimedId) {
      console.error('stripe-webhook: no client_reference_id in session');
      return new Response('Missing tenant', { status: 400 });
    }

    // ── Security: cross-verify claimed tenant_id against the payer's email ──
    //
    // client_reference_id is appended to the Stripe Payment Link URL by the
    // browser — any user can edit it before clicking the link. Without this
    // check, an attacker could change it to any other tenant's UUID and cause
    // the webhook to upgrade (or tamper with) the wrong account.
    //
    // We look up the billing_email registered for the claimed tenant and
    // require it to match session.customer_email (which comes from Stripe's
    // servers, not the client). Mismatch → refuse the update.
    //
    // If customer_email is absent (rare edge case in some Stripe flows) we
    // allow the update because we cannot distinguish tamper from a legitimate
    // payment — log a warning so it can be reviewed manually.
    if (customerEmail) {
      const { data: tenant, error } = await sb
        .from('tenants')
        .select('billing_email')
        .eq('id', claimedId)
        .single();

      if (error || !tenant) {
        console.error(`stripe-webhook: tenant ${claimedId} not found`);
        return new Response('Tenant not found', { status: 400 });
      }

      const registeredEmail = (tenant.billing_email as string | null)?.toLowerCase().trim() ?? null;

      if (registeredEmail && registeredEmail !== customerEmail) {
        // Emails don't match: the client_reference_id was tampered with.
        console.error(
          `stripe-webhook: TAMPER DETECTED — claimed tenant ${claimedId} ` +
          `has billing_email "${registeredEmail}" but payment came from "${customerEmail}". ` +
          `Stripe customer: ${customerId}. Refusing update.`
        );
        // Return 200 so Stripe does not retry (this is intentional fraud, not
        // a transient error). The payment itself is legitimate on Stripe's side
        // — do not disrupt it. Log for manual review instead.
        return new Response(JSON.stringify({ received: true, action: 'rejected_tamper' }), {
          headers: { 'Content-Type': 'application/json' },
        });
      }

      if (!registeredEmail) {
        console.warn(`stripe-webhook: tenant ${claimedId} has no billing_email on record — proceeding without email verification`);
      }
    } else {
      console.warn(`stripe-webhook: session has no customer_email — proceeding without email verification for tenant ${claimedId}`);
    }

    // Note: line_items are not expanded in Stripe webhook payloads by default,
    // so session.line_items is always null here. priceId comes from
    // session.metadata.price_id which must be set in the Payment Link metadata.
    // If absent, plan defaults to 'basic' and a warning is logged.
    if (!priceId) {
      console.warn(`stripe-webhook: no price_id in session metadata for tenant ${claimedId} — defaulting to basic`);
    }
    const plan = PRICE_TO_PLAN[priceId] ?? 'basic';

    const { error: updateError } = await sb.from('tenants').update({
      plan,
      stripe_customer_id:      customerId,
      stripe_subscription_id:  subId,
      trial_ends_at:           null,   // clear trial — now on paid plan
    }).eq('id', claimedId);

    if (updateError) {
      console.error(`stripe-webhook: failed to upgrade tenant ${claimedId} to ${plan}: ${updateError.message}`);
      return new Response('DB update failed', { status: 500 });
    }

    console.log(`stripe-webhook: tenant ${claimedId} upgraded to ${plan} (customer: ${customerId})`);
  }

  if (event.type === 'customer.subscription.deleted') {
    const sub        = event.data.object;
    const customerId = sub.customer;

    // Subscription cancellations use stripe_customer_id — server-assigned,
    // not client-controlled, so no tamper risk here.
    await sb.from('tenants')
      .update({ plan: 'cancelled', stripe_subscription_id: null })
      .eq('stripe_customer_id', customerId);

    console.log(`stripe-webhook: subscription cancelled for customer ${customerId}`);
  }

  if (event.type === 'invoice.payment_failed') {
    const invoice    = event.data.object;
    const customerId = invoice.customer;
    console.warn(`stripe-webhook: payment failed for customer ${customerId}`);
    // Optionally: send WhatsApp reminder via Make.com webhook
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
