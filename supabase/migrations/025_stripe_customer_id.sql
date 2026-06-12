-- Migration 025: Add stripe_customer_id to tenants for subscription management
-- Needed by stripe-webhook Edge Function to downgrade on subscription cancellation.

ALTER TABLE tenants
  ADD COLUMN IF NOT EXISTS stripe_customer_id text;

CREATE INDEX IF NOT EXISTS tenants_stripe_customer_id_idx
  ON tenants (stripe_customer_id)
  WHERE stripe_customer_id IS NOT NULL;
