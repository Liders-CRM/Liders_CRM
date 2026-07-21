-- Migration 099: Lock down internal-only referral-reward functions
--
-- Supabase security advisor (run right after 097/098) flagged that
-- _process_referral_conversion_reward() and _referral_conversion_trigger()
-- picked up Supabase's default GRANT to anon/authenticated on every new
-- function in the public schema (same class of gap CLAUDE.md documents for
-- _seat_config()/log_lead_stage_change() elsewhere, and the exact bug
-- migration 044 fixed for admin_extend_trial/admin_set_tenant_notes/
-- admin_toggle_marketing_addon). Both are meant to be called ONLY from the
-- referral_conversion_reward_trg trigger (which runs with the function
-- owner's privileges, not through PostgREST role grants) — never directly
-- over /rest/v1/rpc/*. Left exposed, any authenticated (or even anonymous)
-- caller could invoke _process_referral_conversion_reward(any_tenant_id, ...)
-- directly and force-credit arbitrary referral rewards, bypassing the actual
-- trial->paid transition the trigger is supposed to gate on.
--
-- Revoking EXECUTE from anon/authenticated does not affect the trigger's own
-- internal PERFORM/function calls — those run under the calling SECURITY
-- DEFINER function's owner privileges, not through the PostgREST grant
-- system that only governs external /rest/v1/rpc/* calls.

REVOKE EXECUTE ON FUNCTION public._process_referral_conversion_reward(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._referral_conversion_trigger() FROM PUBLIC, anon, authenticated;

-- Also fix the "mutable search_path" warning on _plan_price_config (same
-- class of issue pre-existing on _seat_config(), not fixed here since that's
-- out of scope, but no reason to introduce it fresh on a new function).
CREATE OR REPLACE FUNCTION public._plan_price_config(p_plan text)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path = 'public' AS $$
  SELECT (
    '{
      "basic":   {"monthly": 179, "annual_monthly_equiv": 124.17},
      "pro":     {"monthly": 349, "annual_monthly_equiv": 249.17},
      "premium": {"monthly": 549, "annual_monthly_equiv": 399.17}
    }'::jsonb -> p_plan
  );
$$;
