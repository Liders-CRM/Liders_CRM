-- Migration 024: Fix plan CHECK constraint — replace 'enterprise' with 'premium'
-- Background: index.html uses 'premium' as plan name but migration 001 CHECK
-- only allowed 'trial','basic','pro','enterprise'. This caused writes to fail
-- silently when Stripe webhook tried to set plan='premium'.

ALTER TABLE tenants DROP CONSTRAINT IF EXISTS tenants_plan_check;

ALTER TABLE tenants
  ADD CONSTRAINT tenants_plan_check
  CHECK (plan IN ('trial', 'basic', 'pro', 'premium', 'internal', 'lifetime'));

-- 'internal' and 'lifetime' support admin-granted permanent access
-- (already in use for liders.crm@gmail.com + elgrablidudu@gmail.com)
