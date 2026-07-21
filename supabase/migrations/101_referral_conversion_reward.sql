-- Migration 097: Referral-to-paid-conversion reward
--
-- New reward layer on top of the existing lead_referrals (061) referral
-- loop: today, a referrer gets +250 XP the moment a referred colleague
-- ACCEPTS a referral (client-side XP, unchanged, not touched here). This
-- migration adds a second, separate reward: when the REFERRED tenant
-- (lead_referrals.accepted_by_tenant_id) later upgrades from plan='trial'
-- to any paid plan, the REFERRER (lead_referrals.from_tenant_id) gets a
-- free month credited on their OWN current plan tier.
--
-- Trigger design: an AFTER UPDATE OF plan trigger on tenants reacts to any
-- trial->paid transition regardless of what caused it (today: admin_set_plan,
-- called manually from admin.html since PAYMENTS_LIVE=false; tomorrow: the
-- currently-dormant stripe-webhook or a future Grow/PayMe webhook) — no
-- further wiring is needed on the billing side when real payments go live.
-- Postgres row triggers fire on any UPDATE regardless of caller/RPC.
--
-- IMPORTANT CAVEAT (communicated to the business owner): tenant_access_active()
-- (012/043) already treats every non-trial/non-cancelled plan as active
-- REGARDLESS of plan_expires_at. Extending plan_expires_at here is real,
-- auditable bookkeeping, but has no functional access effect yet — it will
-- only matter once a future billing-enforcement mechanism actually reads
-- plan_expires_at for paid tenants. That mechanism does not exist yet and is
-- out of scope here.
--
-- Concurrency/idempotency:
--   • UNIQUE(lead_referral_id): a given referral is only ever rewarded once.
--   • UNIQUE(converted_tenant_id): at most ONE reward, ever, per referred
--     tenant — even if several pending referrals point at them, or they
--     cross trial->paid more than once. This is a deliberate business rule
--     (first eligible referral wins), not just an engineering guard.
--   • Row selection uses a blocking `FOR UPDATE` (not SKIP LOCKED) — SKIP
--     LOCKED is for "any interchangeable row", not "the one canonical
--     answer for this tenant"; a concurrent caller must wait and then find
--     nothing left to do, never grab a different row and double-credit.
--   • unique_violation on INSERT is caught and swallowed — it must never
--     propagate up and roll back the tenant's own plan-change transaction.
--   • "Earliest accepted" is approximated by created_at (referral send time)
--     since lead_referrals has no accepted_at column — noted explicitly,
--     not silently assumed.

ALTER TABLE tenants ADD COLUMN IF NOT EXISTS billing_period text
  CHECK (billing_period IN ('monthly','annual'));
-- Deliberately NOT added to migration 017's authenticated column allowlist —
-- admin-managed only, same treatment as stripe_customer_id/billing_email.

CREATE TABLE IF NOT EXISTS referral_conversion_rewards (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_referral_id         uuid NOT NULL UNIQUE REFERENCES lead_referrals(id),
  referrer_tenant_id       uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  converted_tenant_id      uuid NOT NULL UNIQUE REFERENCES tenants(id) ON DELETE CASCADE,
  trigger_reason           text NOT NULL,
  credit_status            text NOT NULL CHECK (credit_status IN (
                             'credited','queued_referrer_on_trial',
                             'noop_lifetime','noop_cancelled')),
  referrer_plan_before     text,
  referrer_plan_after      text,
  plan_expires_at_before   timestamptz,
  plan_expires_at_after    timestamptz,
  billing_period_at_credit text,
  monetary_value_ils       numeric(10,2) NOT NULL DEFAULT 0,
  created_at               timestamptz NOT NULL DEFAULT now(),
  processed_at             timestamptz
);

CREATE INDEX IF NOT EXISTS idx_referral_conversion_rewards_referrer
  ON referral_conversion_rewards(referrer_tenant_id);

ALTER TABLE referral_conversion_rewards ENABLE ROW LEVEL SECURITY;
-- No policies on purpose: all access via SECURITY DEFINER RPCs (pattern 040/046/061).

-- Server-side plan price config, mirroring the _seat_config() precedent
-- (050_seat_pricing_update.sql) — used ONLY to compute the audit/reporting
-- monetary value of a credited month, never for checkout/display (that
-- stays index.html's Billing.PLANS). annual_monthly_equiv = annualTotal/12
-- from Billing.PLANS (1490/2990/4790 respectively).
CREATE OR REPLACE FUNCTION public._plan_price_config(p_plan text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT (
    '{
      "basic":   {"monthly": 179, "annual_monthly_equiv": 124.17},
      "pro":     {"monthly": 349, "annual_monthly_equiv": 249.17},
      "premium": {"monthly": 549, "annual_monthly_equiv": 399.17}
    }'::jsonb -> p_plan
  );
$$;

-- Extend append_audit()'s action whitelist for consistency (this migration's
-- trigger path bypasses append_audit() entirely — see below — but the action
-- string should still be recognized if ever invoked from an authenticated
-- context in the future, e.g. a manual admin re-check RPC).
CREATE OR REPLACE FUNCTION public.append_audit(
  p_action      text,
  p_entity_type text  DEFAULT NULL,
  p_entity_id   uuid  DEFAULT NULL,
  p_details     jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tenant_id uuid := get_my_tenant_id();
  v_agent_id  uuid := get_my_agent_id();
BEGIN
  IF p_action NOT IN (
    'lead.created', 'lead.updated', 'lead.deleted', 'lead.stage_changed',
    'settings.updated', 'auth.login', 'property.created', 'property.deleted',
    'task.created', 'task.completed', 'security.injection_blocked',
    'reward.referral_conversion_credited', 'page.created'
  ) THEN
    RETURN;
  END IF;

  INSERT INTO public.audit_log (tenant_id, agent_id, action, entity_type, entity_id, new_value)
  VALUES (v_tenant_id, v_agent_id, p_action, p_entity_type, p_entity_id, p_details);
END;
$$;

-- ── _process_referral_conversion_reward(): core credit logic ──
-- p_converted_tenant_id is the tenant whose plan just flipped trial->paid
-- (the REFERRED party). The beneficiary of the credit is that referral's
-- from_tenant_id (the REFERRER) — not the same tenant.
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
  -- Find + lock the earliest un-rewarded referral where p_converted_tenant_id
  -- is the accepting party. Blocking FOR UPDATE (not SKIP LOCKED): a second
  -- overlapping caller for the same converted tenant blocks here until the
  -- first commits, then finds nothing left via NOT EXISTS and exits cleanly.
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

  -- Belt-and-suspenders: skip fast if this referrer already has any reward,
  -- ever (the UNIQUE(converted_tenant_id) constraint enforces this at
  -- insert time regardless — this just avoids an unnecessary row lock).
  IF EXISTS (SELECT 1 FROM referral_conversion_rewards WHERE converted_tenant_id = v_ref.from_tenant_id) THEN
    RETURN;
  END IF;

  SELECT * INTO v_referrer FROM tenants WHERE id = v_ref.from_tenant_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;

  v_price := public._plan_price_config(v_referrer.plan);

  IF v_referrer.plan = 'lifetime' THEN
    v_status := 'noop_lifetime'; v_value := 0; v_new_exp := NULL;
  ELSIF v_referrer.plan = 'cancelled' THEN
    v_status := 'noop_cancelled'; v_value := 0; v_new_exp := NULL;
  ELSIF v_referrer.plan = 'trial' THEN
    -- Queued: will be processed by the trigger's second branch once this
    -- referrer's OWN plan flips trial->paid.
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
      v_ref.id, v_referrer.id, v_referrer.id, p_trigger_reason,
      v_status, v_referrer.plan, v_referrer.plan,
      v_referrer.plan_expires_at, v_new_exp, v_referrer.billing_period,
      v_value, CASE WHEN v_status = 'credited' THEN now() END
    );
  EXCEPTION WHEN unique_violation THEN
    -- Lost a race to a concurrent caller — treat as success, no-op. Must
    -- NOT propagate, or the tenant's plan-change UPDATE that triggered this
    -- would roll back over an unrelated referral-reward race.
    RETURN;
  END;

  -- append_audit() cannot be used here: it resolves tenant/agent id from
  -- get_my_tenant_id()/get_my_agent_id(), i.e. auth.uid() of the CALLER
  -- (the admin who ran admin_set_plan, or the service role behind a future
  -- webhook) — not the referrer this credit actually belongs to. Direct
  -- insert with explicit tenant_id/entity_id instead.
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

-- ── trigger function: handles both directions ──
--   1) NEW is the tenant that just converted (the REFERRED party) -> credit its referrer.
--   2) NEW is itself a referrer with a queued_referrer_on_trial reward,
--      and NEW itself just converted trial->paid -> process that queued reward now.
CREATE OR REPLACE FUNCTION public._referral_conversion_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $fn$
DECLARE
  v_price jsonb;
BEGIN
  PERFORM public._process_referral_conversion_reward(NEW.id, 'plan_change');

  v_price := public._plan_price_config(NEW.plan);
  UPDATE referral_conversion_rewards w SET
    credit_status            = 'credited',
    processed_at              = now(),
    referrer_plan_before       = NEW.plan,
    referrer_plan_after        = NEW.plan,
    plan_expires_at_before     = NEW.plan_expires_at,
    plan_expires_at_after      = GREATEST(COALESCE(NEW.plan_expires_at, now()), now()) + interval '1 month',
    billing_period_at_credit   = NEW.billing_period,
    monetary_value_ils         = CASE
      WHEN NEW.billing_period = 'annual' AND v_price IS NOT NULL THEN (v_price->>'annual_monthly_equiv')::numeric
      WHEN v_price IS NOT NULL THEN (v_price->>'monthly')::numeric
      ELSE 0 END
  WHERE w.referrer_tenant_id = NEW.id AND w.credit_status = 'queued_referrer_on_trial';

  UPDATE tenants SET plan_expires_at = GREATEST(COALESCE(plan_expires_at, now()), now()) + interval '1 month'
  WHERE id = NEW.id
    AND EXISTS (
      SELECT 1 FROM referral_conversion_rewards
      WHERE referrer_tenant_id = NEW.id AND processed_at = now() AND credit_status = 'credited'
    );

  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS referral_conversion_reward_trg ON tenants;
CREATE TRIGGER referral_conversion_reward_trg
  AFTER UPDATE OF plan ON tenants
  FOR EACH ROW
  WHEN (OLD.plan = 'trial' AND NEW.plan IN ('basic','pro','premium'))
  EXECUTE FUNCTION public._referral_conversion_trigger();

-- ── admin_set_billing_period(): mirrors admin_extend_trial's exact guard pattern ──
CREATE OR REPLACE FUNCTION public.admin_set_billing_period(p_tenant_id uuid, p_period text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_caller text := auth.email();
BEGIN
  IF v_caller NOT IN ('info@plto.app', 'elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;
  IF p_period IS NOT NULL AND p_period NOT IN ('monthly','annual') THEN
    RAISE EXCEPTION 'invalid billing period: %', p_period;
  END IF;
  UPDATE tenants SET billing_period = p_period WHERE id = p_tenant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'tenant not found';
  END IF;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_set_billing_period(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.admin_set_billing_period(uuid, text) TO authenticated;

-- ── get_saas_tenants_admin(): extend with billing_period (same RETURNS TABLE-append pattern as 036) ──
-- Return type is changing (new trailing column), so CREATE OR REPLACE alone
-- is rejected by Postgres (42P13) — must drop first.
DROP FUNCTION IF EXISTS public.get_saas_tenants_admin();
CREATE OR REPLACE FUNCTION public.get_saas_tenants_admin()
RETURNS TABLE (
  id              uuid,
  name            text,
  billing_email   text,
  plan            text,
  trial_ends_at   timestamptz,
  created_at      timestamptz,
  lead_count      bigint,
  task_count      bigint,
  agent_count     bigint,
  marketing_addon boolean,
  notes           text,
  billing_period  text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_email text := auth.email();
BEGIN
  IF v_email NOT IN ('info@plto.app','elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;

  RETURN QUERY
  SELECT
    t.id, t.name, t.billing_email, t.plan, t.trial_ends_at, t.created_at,
    (SELECT COUNT(*) FROM leads l  WHERE l.tenant_id  = t.id)::bigint,
    (SELECT COUNT(*) FROM tasks tk WHERE tk.tenant_id = t.id)::bigint,
    (SELECT COUNT(*) FROM agent_users au WHERE au.tenant_id = t.id)::bigint,
    COALESCE(t.marketing_addon, false),
    t.notes,
    t.billing_period
  FROM tenants t
  ORDER BY t.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_saas_tenants_admin() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_saas_tenants_admin() TO authenticated;

-- ── list_referral_conversion_rewards(): admin reporting view ──
CREATE OR REPLACE FUNCTION public.list_referral_conversion_rewards()
RETURNS TABLE (
  id uuid, referrer_name text, converted_name text, credit_status text,
  monetary_value_ils numeric, plan_expires_at_after timestamptz, created_at timestamptz
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_email text := auth.email();
BEGIN
  IF v_email NOT IN ('info@plto.app','elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;

  RETURN QUERY
  SELECT w.id, tr.name, tc.name, w.credit_status, w.monetary_value_ils,
         w.plan_expires_at_after, w.created_at
  FROM referral_conversion_rewards w
  JOIN tenants tr ON tr.id = w.referrer_tenant_id
  JOIN tenants tc ON tc.id = w.converted_tenant_id
  ORDER BY w.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_referral_conversion_rewards() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_referral_conversion_rewards() TO authenticated;
