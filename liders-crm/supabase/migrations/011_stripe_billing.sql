-- Liders CRM — Migration 011: Stripe Billing
-- Adds billing columns to tenants for Stripe integration

ALTER TABLE tenants
  ADD COLUMN IF NOT EXISTS stripe_customer_id     text,
  ADD COLUMN IF NOT EXISTS stripe_subscription_id text,
  ADD COLUMN IF NOT EXISTS trial_ends_at          timestamptz DEFAULT (now() + interval '30 days'),
  ADD COLUMN IF NOT EXISTS billing_email          text,
  ADD COLUMN IF NOT EXISTS plan_expires_at        timestamptz;

-- Extend plan check to include 'cancelled'
ALTER TABLE tenants DROP CONSTRAINT IF EXISTS tenants_plan_check;
ALTER TABLE tenants ADD CONSTRAINT tenants_plan_check
  CHECK (plan IN ('trial','basic','pro','cancelled'));

-- Give demo tenant a 30-day trial window
UPDATE tenants
SET trial_ends_at = now() + interval '30 days',
    billing_email = 'demo@liders.co.il'
WHERE id = '00000000-0000-0000-0000-000000000001'
  AND trial_ends_at IS NULL;
