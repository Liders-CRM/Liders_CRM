-- Liders CRM — Migration 018: Unique index on tenants.billing_email
--
-- The Stripe webhook cross-check (introduced in stripe-webhook/index.ts)
-- verifies that session.customer_email matches the tenant's billing_email
-- before honouring a checkout.session.completed event — closing the
-- client_reference_id tamper vector where an attacker could change the UUID
-- in the checkout URL to point at another tenant.
--
-- For that check to be reliable, billing_email must be unique: one auth
-- identity → one tenant → one billing_email (enforced by the unique index
-- on agent_users.auth_user_id from migration 015). The partial condition
-- (WHERE billing_email IS NOT NULL) avoids blocking the demo tenant and any
-- legacy rows that pre-date billing.

CREATE UNIQUE INDEX IF NOT EXISTS tenants_billing_email_unique
  ON tenants (billing_email)
  WHERE billing_email IS NOT NULL;
