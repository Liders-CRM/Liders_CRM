-- Add server-side onboarding flag (backup approach — JS now uses created_at
-- heuristic, but this column can be used for future server-side checks)
ALTER TABLE tenants
  ADD COLUMN IF NOT EXISTS onboarding_completed boolean NOT NULL DEFAULT false;

-- Mark all existing tenants as done
UPDATE tenants
SET onboarding_completed = true
WHERE id IN (SELECT DISTINCT tenant_id FROM agent_users);

GRANT UPDATE (onboarding_completed) ON tenants TO authenticated;
