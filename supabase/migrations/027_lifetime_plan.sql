-- Add 'lifetime' plan tier for owner / permanently-free accounts
ALTER TABLE tenants
  DROP CONSTRAINT IF EXISTS tenants_plan_check;

ALTER TABLE tenants
  ADD CONSTRAINT tenants_plan_check
  CHECK (plan IN ('trial','basic','pro','premium','cancelled','lifetime'));
