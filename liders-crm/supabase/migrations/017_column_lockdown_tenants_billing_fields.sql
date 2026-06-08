-- Liders CRM — Migration 017: Column-level lockdown of tenants billing fields
--
-- security-adversary review flagged that the "agents read own tenant" RLS
-- policy (migration 014) is row-level only — RLS structurally cannot
-- restrict which *columns* a SELECT returns, only which *rows*. Combined
-- with the blanket `GRANT SELECT ... ON ALL TABLES IN SCHEMA public TO
-- authenticated` from migration 009, any authenticated agent querying their
-- own tenant row — including a careless `.from('tenants').select('*')` —
-- would receive stripe_customer_id, stripe_subscription_id and
-- billing_email verbatim. index.html's own read site was narrowed to a safe
-- column list, but the *policy* remains a trap for the next read site.
--
-- Postgres column privileges are additive on top of table-level privileges:
-- a table-level SELECT grant lets a role read every column regardless of
-- any column-level REVOKE (the table grant alone is sufficient — there is
-- no way to subtract from it at the column level). The only way to truly
-- restrict columns is to revoke the table-level SELECT and re-grant SELECT
-- on an explicit safe column list.
--
-- INSERT/UPDATE/DELETE are untouched — `tenants` has no authenticated-facing
-- write policy (RLS already default-denies those for `authenticated`; all
-- writes go through update_tenant_profile() / the service-role webhook).

REVOKE SELECT ON tenants FROM authenticated;

GRANT SELECT (
  id, name, slug, logo_url, primary_color, phone, whatsapp_number,
  make_webhook_url, plan, plan_expires_at, industry, city, country,
  is_active, created_at, updated_at, trial_ends_at
) ON tenants TO authenticated;

-- stripe_customer_id, stripe_subscription_id, billing_email are now
-- unreachable for `authenticated` no matter how the row is selected —
-- `select('*')` now raises "permission denied for column ..." instead of
-- silently leaking secrets to the client.
