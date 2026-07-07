-- Migration 070: Close direct-REST write bypass on shared_leads
--
-- Pre-launch security audit finding: the "shared_leads_owner" policy from
-- migration 040 is FOR ALL (covers INSERT/UPDATE), constrained only by
-- owner_tenant_id — it never restricts partner_tenant_id/status/pin_hash.
-- Combined with the table-level INSERT/UPDATE grant to `authenticated`,
-- any authenticated agent could issue a direct PostgREST INSERT/UPDATE
-- against /rest/v1/shared_leads to force a share into status='active' with
-- any partner_tenant_id, bypassing the PIN + 5-attempt lockout entirely.
--
-- All legitimate writes already go through SECURITY DEFINER RPCs
-- (create_shared_lead, accept_shared_lead, revoke_shared_lead,
-- update_partner_notes) which run as the function owner and do not need
-- table-level INSERT/UPDATE grants to authenticated. This migration removes
-- the direct write surface, matching the RPC-only pattern used everywhere
-- else (046/061/063/064/065).

REVOKE INSERT, UPDATE ON shared_leads FROM authenticated;

DROP POLICY IF EXISTS "shared_leads_owner" ON shared_leads;
CREATE POLICY "shared_leads_owner_read" ON shared_leads
  FOR SELECT TO authenticated
  USING (owner_tenant_id = get_my_tenant_id());
