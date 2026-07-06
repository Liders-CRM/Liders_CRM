-- Migration 048: agent_invites — invite teammates into an existing tenant,
-- with per-plan seat limits and paid-seat overage pricing.

CREATE TABLE IF NOT EXISTS agent_invites (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  email       text        NOT NULL,
  role        text        NOT NULL DEFAULT 'agent'
                          CHECK (role IN ('admin','agent','viewer')),
  invited_by  uuid        REFERENCES agent_users(id) ON DELETE SET NULL,
  status      text        NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','accepted','revoked','expired')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  accepted_at timestamptz
);

CREATE INDEX IF NOT EXISTS agent_invites_email_pending_idx
  ON agent_invites (lower(email))
  WHERE status = 'pending';

ALTER TABLE agent_invites ENABLE ROW LEVEL SECURITY;

-- Owners/admins of a tenant can see and manage their own tenant's invites
CREATE POLICY "agent_invites_select" ON agent_invites
  FOR SELECT TO authenticated
  USING (tenant_id = get_my_tenant_id());

-- All writes go through the SECURITY DEFINER RPCs below (role + seat-limit checks)
-- so there are intentionally no INSERT/UPDATE/DELETE policies here.

-- Seat config per plan: included seats, hard max, and price per seat beyond "included"
CREATE OR REPLACE FUNCTION public._seat_config(p_plan text)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT (
    '{
      "trial":     {"included": 1,  "max": 1,  "price": 0},
      "basic":     {"included": 1,  "max": 1,  "price": 0},
      "pro":       {"included": 3,  "max": 7,  "price": 30},
      "premium":   {"included": 10, "max": 50, "price": 30},
      "lifetime":  {"included": 10, "max": 50, "price": 30},
      "cancelled": {"included": 0,  "max": 0,  "price": 0}
    }'::jsonb -> p_plan
  );
$$;

-- Invite a teammate into the caller's own tenant
CREATE OR REPLACE FUNCTION public.invite_agent(p_email text, p_role text DEFAULT 'agent')
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid         uuid := auth.uid();
  v_agent       agent_users%ROWTYPE;
  v_plan        text;
  v_seats       jsonb;
  v_included    int;
  v_max         int;
  v_price       int;
  v_current     int;
  v_new_seat_no int;
  v_overage     int;
  v_invite_id   uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF p_role NOT IN ('admin','agent','viewer') THEN RAISE EXCEPTION 'invalid role'; END IF;

  SELECT * INTO v_agent FROM agent_users WHERE auth_user_id = v_uid LIMIT 1;
  IF v_agent.id IS NULL THEN RAISE EXCEPTION 'no tenant found for caller'; END IF;
  IF v_agent.role NOT IN ('owner','admin') THEN RAISE EXCEPTION 'only the owner or an admin can invite teammates'; END IF;

  SELECT plan INTO v_plan FROM tenants WHERE id = v_agent.tenant_id;
  v_seats    := public._seat_config(v_plan);
  v_included := (v_seats->>'included')::int;
  v_max      := (v_seats->>'max')::int;
  v_price    := (v_seats->>'price')::int;

  SELECT
    (SELECT count(*) FROM agent_users  WHERE tenant_id = v_agent.tenant_id AND is_active = true) +
    (SELECT count(*) FROM agent_invites WHERE tenant_id = v_agent.tenant_id AND status = 'pending')
  INTO v_current;

  IF v_current >= v_max THEN
    RAISE EXCEPTION 'seat_limit_reached: % seats is the max for this plan, upgrade to add more', v_max;
  END IF;

  INSERT INTO agent_invites (tenant_id, email, role, invited_by)
  VALUES (v_agent.tenant_id, lower(trim(p_email)), p_role, v_agent.id)
  RETURNING id INTO v_invite_id;

  v_new_seat_no := v_current + 1;
  v_overage     := GREATEST(0, v_new_seat_no - v_included);

  RETURN jsonb_build_object(
    'invite_id', v_invite_id,
    'invited', true,
    'is_overage', v_overage > 0,
    'seats_used', v_new_seat_no,
    'seats_included', v_included,
    'seats_max', v_max,
    'monthly_overage_charge', v_overage * v_price
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.invite_agent(text,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.invite_agent(text,text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.invite_agent(text,text) TO authenticated;

-- List the caller's tenant invites + current seat usage summary
CREATE OR REPLACE FUNCTION public.list_agent_invites()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid      uuid := auth.uid();
  v_agent    agent_users%ROWTYPE;
  v_plan     text;
  v_seats    jsonb;
  v_active   int;
  v_pending  jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  SELECT * INTO v_agent FROM agent_users WHERE auth_user_id = v_uid LIMIT 1;
  IF v_agent.id IS NULL THEN RAISE EXCEPTION 'no tenant found for caller'; END IF;

  SELECT plan INTO v_plan FROM tenants WHERE id = v_agent.tenant_id;
  v_seats := public._seat_config(v_plan);

  SELECT count(*) INTO v_active FROM agent_users WHERE tenant_id = v_agent.tenant_id AND is_active = true;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', i.id, 'email', i.email, 'role', i.role, 'status', i.status,
    'created_at', i.created_at, 'expires_at', i.expires_at
  ) ORDER BY i.created_at DESC), '[]'::jsonb)
  INTO v_pending
  FROM agent_invites i
  WHERE i.tenant_id = v_agent.tenant_id AND i.status = 'pending';

  RETURN jsonb_build_object(
    'seats_included', (v_seats->>'included')::int,
    'seats_max',      (v_seats->>'max')::int,
    'seat_price',     (v_seats->>'price')::int,
    'seats_active',   v_active,
    'invites',        v_pending
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_agent_invites() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.list_agent_invites() FROM anon;
GRANT  EXECUTE ON FUNCTION public.list_agent_invites() TO authenticated;

-- Revoke a pending invite (owner/admin of that tenant only)
CREATE OR REPLACE FUNCTION public.revoke_agent_invite(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid   uuid := auth.uid();
  v_agent agent_users%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  SELECT * INTO v_agent FROM agent_users WHERE auth_user_id = v_uid LIMIT 1;
  IF v_agent.id IS NULL OR v_agent.role NOT IN ('owner','admin') THEN
    RAISE EXCEPTION 'only the owner or an admin can revoke invites';
  END IF;

  UPDATE agent_invites SET status = 'revoked'
  WHERE id = p_id AND tenant_id = v_agent.tenant_id AND status = 'pending';
END;
$$;

REVOKE EXECUTE ON FUNCTION public.revoke_agent_invite(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.revoke_agent_invite(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.revoke_agent_invite(uuid) TO authenticated;

-- Admin RPC: seat usage across all tenants, for admin.html to flag overage billing
CREATE OR REPLACE FUNCTION public.admin_list_tenant_seats()
RETURNS TABLE (
  tenant_id              uuid,
  tenant_name            text,
  plan                   text,
  seats_active           bigint,
  seats_pending_invites  bigint,
  seats_included         int,
  seats_max              int,
  seat_price             int,
  overage_seats          int,
  monthly_overage_charge int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_email text := auth.email();
BEGIN
  IF v_email NOT IN ('liders.crm@gmail.com','elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;

  RETURN QUERY
  SELECT
    t.id, t.name, t.plan,
    (SELECT count(*) FROM agent_users a WHERE a.tenant_id = t.id AND a.is_active = true) AS seats_active,
    (SELECT count(*) FROM agent_invites i WHERE i.tenant_id = t.id AND i.status = 'pending') AS seats_pending_invites,
    (public._seat_config(t.plan)->>'included')::int AS seats_included,
    (public._seat_config(t.plan)->>'max')::int AS seats_max,
    (public._seat_config(t.plan)->>'price')::int AS seat_price,
    GREATEST(0, (SELECT count(*) FROM agent_users a WHERE a.tenant_id = t.id AND a.is_active = true)::int
                - (public._seat_config(t.plan)->>'included')::int) AS overage_seats,
    GREATEST(0, (SELECT count(*) FROM agent_users a WHERE a.tenant_id = t.id AND a.is_active = true)::int
                - (public._seat_config(t.plan)->>'included')::int) * (public._seat_config(t.plan)->>'price')::int
      AS monthly_overage_charge
  FROM tenants t
  ORDER BY t.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_list_tenant_seats() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_list_tenant_seats() FROM anon;
GRANT  EXECUTE ON FUNCTION public.admin_list_tenant_seats() TO authenticated;
