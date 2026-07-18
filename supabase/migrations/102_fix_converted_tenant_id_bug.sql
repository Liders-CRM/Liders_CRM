-- Migration 102: Fix converted_tenant_id recorded wrong in the reward INSERT
--
-- Found while walking through the exact "3 friends convert while I'm still
-- on trial" scenario with the business owner: _process_referral_conversion_reward()
-- inserted `v_referrer.id` (the REFERRER's own tenant id) into the
-- `converted_tenant_id` column, instead of `p_converted_tenant_id` (the
-- actual friend/tenant that converted trial->paid). Since
-- referral_conversion_rewards has UNIQUE(converted_tenant_id) — intended to
-- mean "one reward per converting tenant, ever" — this bug silently
-- inverted that guard to mean "one reward per REFERRER, ever": the first
-- friend's conversion inserted a row with converted_tenant_id = referrer's
-- id, and every subsequent friend's conversion then hit a unique_violation
-- against that same referrer id and was swallowed as a no-op, even though
-- each friend is a genuinely distinct, legitimately-rewardable conversion.
-- Net effect: a referrer with 3 separate friends converting would only ever
-- get 1 month credited, not 3 — the exact bug the owner's question surfaced.
--
-- Also moves the "already rewarded" pre-check to key off
-- p_converted_tenant_id (the actual converting tenant) instead of
-- v_ref.from_tenant_id (the referrer) — same root confusion.

CREATE OR REPLACE FUNCTION public._process_referral_conversion_reward(
  p_converted_tenant_id uuid,
  p_trigger_reason      text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $fn$
DECLARE
  v_ref      lead_referrals%ROWTYPE;
  v_referrer tenants%ROWTYPE;
  v_price    jsonb;
  v_value    numeric(10,2);
  v_new_exp  timestamptz;
  v_status   text;
BEGIN
  -- Belt-and-suspenders: this converting tenant already produced a reward
  -- (UNIQUE(converted_tenant_id) enforces it at insert time regardless).
  IF EXISTS (SELECT 1 FROM referral_conversion_rewards WHERE converted_tenant_id = p_converted_tenant_id) THEN
    RETURN;
  END IF;

  SELECT r.* INTO v_ref
  FROM lead_referrals r
  WHERE r.accepted_by_tenant_id = p_converted_tenant_id
    AND r.status IN ('accepted','converted')
    AND NOT EXISTS (
      SELECT 1 FROM referral_conversion_rewards w WHERE w.lead_referral_id = r.id
    )
  ORDER BY r.created_at ASC
  LIMIT 1
  FOR UPDATE OF r;

  IF NOT FOUND THEN RETURN; END IF;

  SELECT * INTO v_referrer FROM tenants WHERE id = v_ref.from_tenant_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;

  v_price := public._plan_price_config(v_referrer.plan);

  IF v_referrer.plan = 'lifetime' THEN
    v_status := 'noop_lifetime'; v_value := 0; v_new_exp := NULL;
  ELSIF v_referrer.plan = 'cancelled' THEN
    v_status := 'noop_cancelled'; v_value := 0; v_new_exp := NULL;
  ELSIF v_referrer.plan = 'trial' THEN
    v_status := 'queued_referrer_on_trial'; v_value := 0; v_new_exp := NULL;
  ELSE
    v_status := 'credited';
    v_new_exp := GREATEST(COALESCE(v_referrer.plan_expires_at, now()), now()) + interval '1 month';
    v_value := CASE
      WHEN v_referrer.billing_period = 'annual' AND v_price IS NOT NULL
        THEN (v_price->>'annual_monthly_equiv')::numeric
      WHEN v_price IS NOT NULL THEN (v_price->>'monthly')::numeric
      ELSE 0
    END;
    UPDATE tenants SET plan_expires_at = v_new_exp WHERE id = v_referrer.id;
  END IF;

  BEGIN
    INSERT INTO referral_conversion_rewards (
      lead_referral_id, referrer_tenant_id, converted_tenant_id, trigger_reason,
      credit_status, referrer_plan_before, referrer_plan_after,
      plan_expires_at_before, plan_expires_at_after, billing_period_at_credit,
      monetary_value_ils, processed_at
    ) VALUES (
      v_ref.id, v_referrer.id, p_converted_tenant_id, p_trigger_reason,
      v_status, v_referrer.plan, v_referrer.plan,
      v_referrer.plan_expires_at, v_new_exp, v_referrer.billing_period,
      v_value, CASE WHEN v_status = 'credited' THEN now() END
    );
  EXCEPTION WHEN unique_violation THEN
    RETURN;
  END;

  INSERT INTO audit_log (tenant_id, action, entity_type, entity_id, new_value)
  VALUES (
    v_referrer.id, 'reward.referral_conversion_credited', 'lead_referral', v_ref.id,
    jsonb_build_object(
      'converted_tenant_id', p_converted_tenant_id,
      'trigger_reason', p_trigger_reason,
      'credit_status', v_status,
      'referrer_plan', v_referrer.plan,
      'plan_expires_at_before', v_referrer.plan_expires_at,
      'plan_expires_at_after', v_new_exp,
      'monetary_value_ils', v_value
    )
  );
END;
$fn$;
