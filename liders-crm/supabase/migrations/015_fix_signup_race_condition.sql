-- Liders CRM — Migration 015: Fix signup race condition in ensure_agent_and_tenant
--
-- security-hardener review of migration 014 found a real concurrency bug:
-- ensure_agent_and_tenant()'s "idempotent fast path" was a plain
-- `SELECT ... LIMIT 1` followed by separate INSERTs, with no unique
-- constraint on agent_users.auth_user_id (only a non-unique index from
-- migration 002). Two concurrent calls for the same brand-new auth identity
-- (e.g. a double-tap on "Sign up", two tabs completing Google OAuth at once,
-- or a network retry) would both see "no agent yet" and both proceed to
-- INSERT — producing two tenants + two agent_users rows for one person, and
-- making get_my_tenant_id() (`SELECT ... LIMIT 1`, no ORDER BY) resolve to a
-- different tenant nondeterministically across requests.
--
-- Fix: (1) add a partial unique index so Postgres itself rejects the second
-- agent_users row for the same auth_user_id, and (2) rewrite the function to
-- catch that unique_violation, roll back its own half-created tenant via the
-- implicit sub-transaction savepoint, and return the winning row instead —
-- making the bootstrap genuinely idempotent under concurrency, not just in
-- the common case.

-- ─────────────────────────────────────────────
-- 1. One auth identity → at most one agent_users row.
--    Partial (WHERE auth_user_id IS NOT NULL) because the column is nullable
--    (ON DELETE SET NULL when the underlying auth.users row is removed) —
--    Postgres unique indexes already treat NULLs as distinct, but being
--    explicit documents the intent and matches the FK's nullability.
-- ─────────────────────────────────────────────
CREATE UNIQUE INDEX IF NOT EXISTS agent_users_auth_user_id_unique
  ON agent_users (auth_user_id)
  WHERE auth_user_id IS NOT NULL;

-- ─────────────────────────────────────────────
-- 2. ensure_agent_and_tenant() — race-safe rewrite
--
--    Same external contract/behavior as migration 014 for the
--    non-concurrent case. New: the tenant + pipeline_stages + agent_users
--    inserts run inside a nested BEGIN/EXCEPTION block (an implicit
--    savepoint). If a concurrent call wins the race and the unique index
--    above rejects our agent_users INSERT, Postgres rolls back everything
--    in that block — no orphaned tenant/pipeline_stages rows — and we
--    re-select and return the winner's {agent_id, tenant_id} with
--    is_new = false, exactly as the idempotent fast path would have.
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ensure_agent_and_tenant(p_agency_name text DEFAULT NULL, p_name text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid          uuid := auth.uid();
  v_email        text := auth.email();
  v_agent_id     uuid;
  v_tenant_id    uuid;
  v_slug         text;
  v_display_name text;
  v_agency_name  text;
BEGIN
  IF v_uid IS NULL OR v_email IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  -- Idempotent fast path: this auth identity already has a home.
  SELECT id, tenant_id INTO v_agent_id, v_tenant_id
  FROM agent_users WHERE auth_user_id = v_uid LIMIT 1;

  IF v_agent_id IS NOT NULL THEN
    RETURN jsonb_build_object('agent_id', v_agent_id, 'tenant_id', v_tenant_id, 'is_new', false);
  END IF;

  v_display_name := coalesce(nullif(trim(p_name), ''), split_part(v_email, '@', 1));
  v_agency_name  := coalesce(nullif(trim(p_agency_name), ''), 'הסוכנות של ' || v_display_name);

  -- Random, collision-proof slug — display name lives in `name`; `slug` is
  -- just an internal unique key (not used for routing in this app today).
  v_slug := 'agency-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12);

  BEGIN
    INSERT INTO tenants (name, slug, plan, trial_ends_at, billing_email)
    VALUES (v_agency_name, v_slug, 'trial', now() + interval '30 days', v_email)
    RETURNING id INTO v_tenant_id;

    INSERT INTO pipeline_stages (tenant_id, name, color, order_idx, is_terminal, is_won) VALUES
      (v_tenant_id, 'ליד חדש',     '#94A3B8', 1, false, false),
      (v_tenant_id, 'בקשר',        '#3B82F6', 2, false, false),
      (v_tenant_id, 'ביקור נקבע', '#8B5CF6', 3, false, false),
      (v_tenant_id, 'הצעה הוגשה', '#F59E0B', 4, false, false),
      (v_tenant_id, 'סגירה ✓',     '#10B981', 5, true,  true);

    INSERT INTO agent_users (tenant_id, auth_user_id, name, email, role)
    VALUES (v_tenant_id, v_uid, v_display_name, v_email, 'owner')
    RETURNING id INTO v_agent_id;

  EXCEPTION WHEN unique_violation THEN
    -- Lost the race: a concurrent call for the SAME auth identity beat us to
    -- the agent_users insert. The savepoint rollback already discarded our
    -- half-created tenant + pipeline_stages — return the winner's row.
    SELECT id, tenant_id INTO v_agent_id, v_tenant_id
    FROM agent_users WHERE auth_user_id = v_uid LIMIT 1;

    IF v_agent_id IS NULL THEN
      RAISE;  -- Different unique violation (e.g. astronomically unlikely slug
              -- collision) — surface it so the client can show an error/retry.
    END IF;

    RETURN jsonb_build_object('agent_id', v_agent_id, 'tenant_id', v_tenant_id, 'is_new', false);
  END;

  RETURN jsonb_build_object('agent_id', v_agent_id, 'tenant_id', v_tenant_id, 'is_new', true);
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.ensure_agent_and_tenant(text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.ensure_agent_and_tenant(text, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.ensure_agent_and_tenant(text, text) TO authenticated;
