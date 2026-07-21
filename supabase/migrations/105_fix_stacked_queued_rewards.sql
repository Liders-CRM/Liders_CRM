-- Migration 101: Fix reward stacking for multiple queued referrals
--
-- Bug found while explaining the exact behavior to the business owner: when
-- a referrer has MULTIPLE queued_referrer_on_trial rewards (e.g. 3 different
-- referred colleagues each converted to paid while the referrer was still on
-- trial themselves), the previous trigger logic bulk-UPDATEd all matching
-- reward rows to 'credited' in one statement, but only extended
-- tenants.plan_expires_at by a single 1-month interval total — regardless of
-- how many queued rewards existed. The reward ledger would then show 3
-- "credited" rows each claiming a full month, while the tenant's actual
-- plan_expires_at only moved forward by 1 month. No cap is intended by
-- design (deliberate growth-flywheel mechanic, confirmed with the business
-- owner) — each converted referral is worth one full month, and they should
-- all stack once the referrer itself becomes a paying customer.
--
-- Fix: loop over queued rewards one at a time, extending plan_expires_at by
-- a full month for EACH row, so N queued rewards yield N stacked months.

CREATE OR REPLACE FUNCTION public._referral_conversion_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $fn$
DECLARE
  v_price     jsonb;
  v_value     numeric(10,2);
  v_new_exp   timestamptz;
  v_queued    record;
BEGIN
  -- Case 1: NEW is the tenant that just converted (the referred party) -> credit its referrer.
  PERFORM public._process_referral_conversion_reward(NEW.id, 'plan_change');

  -- Case 2: NEW is itself a referrer with one or more queued rewards, and NEW
  -- itself just converted trial->paid -> process ALL of them now, stacking a
  -- full month per queued reward (not a single month regardless of count).
  v_price := public._plan_price_config(NEW.plan);
  v_value := CASE
    WHEN NEW.billing_period = 'annual' AND v_price IS NOT NULL THEN (v_price->>'annual_monthly_equiv')::numeric
    WHEN v_price IS NOT NULL THEN (v_price->>'monthly')::numeric
    ELSE 0
  END;

  FOR v_queued IN
    SELECT * FROM referral_conversion_rewards
    WHERE referrer_tenant_id = NEW.id AND credit_status = 'queued_referrer_on_trial'
    ORDER BY created_at ASC
    FOR UPDATE
  LOOP
    SELECT plan_expires_at INTO v_new_exp FROM tenants WHERE id = NEW.id FOR UPDATE;
    v_new_exp := GREATEST(COALESCE(v_new_exp, now()), now()) + interval '1 month';
    UPDATE tenants SET plan_expires_at = v_new_exp WHERE id = NEW.id;

    UPDATE referral_conversion_rewards SET
      credit_status          = 'credited',
      processed_at            = now(),
      referrer_plan_before     = NEW.plan,
      referrer_plan_after      = NEW.plan,
      plan_expires_at_before   = v_new_exp - interval '1 month',
      plan_expires_at_after    = v_new_exp,
      billing_period_at_credit = NEW.billing_period,
      monetary_value_ils       = v_value
    WHERE id = v_queued.id;

    INSERT INTO audit_log (tenant_id, action, entity_type, entity_id, new_value)
    VALUES (
      NEW.id, 'reward.referral_conversion_credited', 'lead_referral', v_queued.lead_referral_id,
      jsonb_build_object(
        'trigger_reason', 'queued_referrer_converted',
        'credit_status', 'credited',
        'plan_expires_at_after', v_new_exp,
        'monetary_value_ils', v_value
      )
    );
  END LOOP;

  RETURN NEW;
END;
$fn$;
