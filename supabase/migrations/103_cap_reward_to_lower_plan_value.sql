-- Migration 103: Cap referral reward at the LOWER of referrer/converted plan value
--
-- Business gap flagged by the owner: the reward always extended the
-- referrer's plan_expires_at by a full month valued at the REFERRER's own
-- plan, regardless of what the REFERRED party actually purchased. A
-- Premium referrer (₪549/mo) whose referred friend joins Basic (₪179/mo)
-- would get a full free Premium month — a real ₪549 loss against a ₪179
-- gain, and an exploitable arbitrage (refer lots of cheap Basic signups to
-- harvest expensive free months on an unrelated Premium/Pro account).
--
-- Fix: the credited value is capped at LEAST(referrer's own monthly value,
-- converted tenant's monthly value), and the TIME extension is proportional
-- to that capped value relative to the referrer's own monthly rate — e.g. if
-- referrer pays ₪549/mo and the capped value is ₪179 (because the referred
-- friend only bought Basic), the referrer gets `30 * (179/549)` ≈ 9-10 days
-- credited, not a full 30-day month. This guarantees PLTO never gives away
-- more time-value than it gained from the new paying customer, in either
-- direction (referrer's own plan already anchors the ceiling per the
-- original spec — "credit on the referrer's own plan, never a different/
-- higher tier" — this migration adds the missing floor).
--
-- The converted tenant's monthly value is snapshotted at the moment of
-- their OWN conversion (new column converted_monthly_value_at_conversion)
-- so a later plan change on their side can't retroactively change what a
-- referrer collects from an already-queued reward.

ALTER TABLE referral_conversion_rewards
  ADD COLUMN IF NOT EXISTS converted_monthly_value_at_conversion numeric(10,2);

CREATE OR REPLACE FUNCTION public._process_referral_conversion_reward(
  p_converted_tenant_id uuid,
  p_trigger_reason      text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $fn$
DECLARE
  v_ref            lead_referrals%ROWTYPE;
  v_referrer       tenants%ROWTYPE;
  v_converted      tenants%ROWTYPE;
  v_referrer_price jsonb;
  v_converted_price jsonb;
  v_referrer_monthly  numeric(10,2);
  v_converted_monthly numeric(10,2);
  v_capped_monthly    numeric(10,2);
  v_days              numeric;
  v_new_exp        timestamptz;
  v_status         text;
BEGIN
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

  SELECT * INTO v_converted FROM tenants WHERE id = p_converted_tenant_id;

  v_converted_price   := public._plan_price_config(v_converted.plan);
  v_converted_monthly := CASE
    WHEN v_converted.billing_period = 'annual' AND v_converted_price IS NOT NULL
      THEN (v_converted_price->>'annual_monthly_equiv')::numeric
    WHEN v_converted_price IS NOT NULL THEN (v_converted_price->>'monthly')::numeric
    ELSE 0
  END;

  v_referrer_price := public._plan_price_config(v_referrer.plan);

  IF v_referrer.plan = 'lifetime' THEN
    v_status := 'noop_lifetime'; v_capped_monthly := 0; v_new_exp := NULL;
  ELSIF v_referrer.plan = 'cancelled' THEN
    v_status := 'noop_cancelled'; v_capped_monthly := 0; v_new_exp := NULL;
  ELSIF v_referrer.plan = 'trial' THEN
    v_status := 'queued_referrer_on_trial'; v_capped_monthly := 0; v_new_exp := NULL;
  ELSE
    v_status := 'credited';
    v_referrer_monthly := CASE
      WHEN v_referrer.billing_period = 'annual' AND v_referrer_price IS NOT NULL
        THEN (v_referrer_price->>'annual_monthly_equiv')::numeric
      WHEN v_referrer_price IS NOT NULL THEN (v_referrer_price->>'monthly')::numeric
      ELSE 0
    END;
    -- Never grant more time-value than was actually gained from the new
    -- paying customer, in either direction.
    v_capped_monthly := LEAST(v_referrer_monthly, v_converted_monthly);
    v_days := CASE WHEN v_referrer_monthly > 0 THEN 30 * (v_capped_monthly / v_referrer_monthly) ELSE 0 END;
    v_new_exp := GREATEST(COALESCE(v_referrer.plan_expires_at, now()), now()) + (v_days || ' days')::interval;
    UPDATE tenants SET plan_expires_at = v_new_exp WHERE id = v_referrer.id;
  END IF;

  BEGIN
    INSERT INTO referral_conversion_rewards (
      lead_referral_id, referrer_tenant_id, converted_tenant_id, trigger_reason,
      credit_status, referrer_plan_before, referrer_plan_after,
      plan_expires_at_before, plan_expires_at_after, billing_period_at_credit,
      monetary_value_ils, converted_monthly_value_at_conversion, processed_at
    ) VALUES (
      v_ref.id, v_referrer.id, p_converted_tenant_id, p_trigger_reason,
      v_status, v_referrer.plan, v_referrer.plan,
      v_referrer.plan_expires_at, v_new_exp, v_referrer.billing_period,
      v_capped_monthly, v_converted_monthly, CASE WHEN v_status = 'credited' THEN now() END
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
      'converted_plan', v_converted.plan,
      'plan_expires_at_before', v_referrer.plan_expires_at,
      'plan_expires_at_after', v_new_exp,
      'monetary_value_ils', v_capped_monthly
    )
  );
END;
$fn$;

-- Re-processing of queued rewards (referrer was on trial, now converts):
-- must apply the SAME cap, using the converted tenant's value snapshotted
-- at their own conversion time (converted_monthly_value_at_conversion),
-- against the referrer's monthly value at collection time (NEW.plan).
CREATE OR REPLACE FUNCTION public._referral_conversion_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $fn$
DECLARE
  v_referrer_price    jsonb;
  v_referrer_monthly  numeric(10,2);
  v_capped_monthly    numeric(10,2);
  v_days              numeric;
  v_new_exp           timestamptz;
  v_queued            record;
BEGIN
  -- Case 1: NEW is the tenant that just converted (the referred party) -> credit its referrer.
  PERFORM public._process_referral_conversion_reward(NEW.id, 'plan_change');

  -- Case 2: NEW is itself a referrer with one or more queued rewards, and NEW
  -- itself just converted trial->paid -> process ALL of them now, each
  -- capped at the lower of NEW's own plan value and that specific referral's
  -- converted-tenant value (snapshotted at their conversion time).
  v_referrer_price := public._plan_price_config(NEW.plan);
  v_referrer_monthly := CASE
    WHEN NEW.billing_period = 'annual' AND v_referrer_price IS NOT NULL THEN (v_referrer_price->>'annual_monthly_equiv')::numeric
    WHEN v_referrer_price IS NOT NULL THEN (v_referrer_price->>'monthly')::numeric
    ELSE 0
  END;

  FOR v_queued IN
    SELECT * FROM referral_conversion_rewards
    WHERE referrer_tenant_id = NEW.id AND credit_status = 'queued_referrer_on_trial'
    ORDER BY created_at ASC
    FOR UPDATE
  LOOP
    v_capped_monthly := LEAST(v_referrer_monthly, COALESCE(v_queued.converted_monthly_value_at_conversion, 0));
    v_days := CASE WHEN v_referrer_monthly > 0 THEN 30 * (v_capped_monthly / v_referrer_monthly) ELSE 0 END;

    SELECT plan_expires_at INTO v_new_exp FROM tenants WHERE id = NEW.id FOR UPDATE;
    v_new_exp := GREATEST(COALESCE(v_new_exp, now()), now()) + (v_days || ' days')::interval;
    UPDATE tenants SET plan_expires_at = v_new_exp WHERE id = NEW.id;

    UPDATE referral_conversion_rewards SET
      credit_status          = 'credited',
      processed_at            = now(),
      referrer_plan_before     = NEW.plan,
      referrer_plan_after      = NEW.plan,
      plan_expires_at_before   = v_new_exp - (v_days || ' days')::interval,
      plan_expires_at_after    = v_new_exp,
      billing_period_at_credit = NEW.billing_period,
      monetary_value_ils       = v_capped_monthly
    WHERE id = v_queued.id;

    INSERT INTO audit_log (tenant_id, action, entity_type, entity_id, new_value)
    VALUES (
      NEW.id, 'reward.referral_conversion_credited', 'lead_referral', v_queued.lead_referral_id,
      jsonb_build_object(
        'trigger_reason', 'queued_referrer_converted',
        'credit_status', 'credited',
        'plan_expires_at_after', v_new_exp,
        'monetary_value_ils', v_capped_monthly
      )
    );
  END LOOP;

  RETURN NEW;
END;
$fn$;
