-- Liders CRM — Migration 019: security-hardener + adversary followup fixes
--
-- 1. Add 'premium' to tenants_plan_check — webhook maps REPLACE_PRICE_ID_PREMIUM
--    to 'premium' but the constraint only allowed trial/basic/pro/cancelled,
--    causing the UPDATE to silently fail (constraint violation, no error surfaced).
--
-- 2. Backfill billing_email for any tenant where it is NULL — migration 018's
--    cross-check is bypassed for NULL rows (registeredEmail && ... short-circuits).
--    Source of truth: the agent_users row for that tenant's owner.
--
-- 3. Revoke SELECT on make_webhook_url from authenticated — migration 017's
--    explicit column grant included make_webhook_url, newly exposing the
--    Make.com automation webhook URL to all agents of a tenant via direct DB
--    query, even those whose UI doesn't show it. It is an internal credential
--    that should not be readable by the client role.

-- ── 1. Add 'premium' to plan check ──────────────────────────────────────────
ALTER TABLE tenants DROP CONSTRAINT IF EXISTS tenants_plan_check;
ALTER TABLE tenants ADD CONSTRAINT tenants_plan_check
  CHECK (plan IN ('trial', 'basic', 'pro', 'premium', 'cancelled'));

-- ── 2. Backfill billing_email from agent_users.email for owner rows ──────────
UPDATE tenants t
SET billing_email = au.email
FROM agent_users au
WHERE au.tenant_id  = t.id
  AND au.role       = 'owner'
  AND t.billing_email IS NULL
  AND au.email IS NOT NULL;

-- ── 3. Remove make_webhook_url from the authenticated column grant ───────────
-- Migration 017 did REVOKE SELECT ON tenants FROM authenticated, then granted
-- an explicit column list. Column-level REVOKE removes from that grant.
REVOKE SELECT (make_webhook_url) ON tenants FROM authenticated;
