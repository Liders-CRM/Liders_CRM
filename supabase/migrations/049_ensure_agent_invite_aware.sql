-- Migration 049: make ensure_agent_and_tenant() invite-aware.
-- Before creating a brand-new tenant for a first-time login, check for a
-- pending invite matching the caller's email and attach them to that
-- existing tenant instead. Existing behavior (new tenant per new identity)
-- is unchanged when there is no matching invite.

CREATE OR REPLACE FUNCTION public.ensure_agent_and_tenant(p_agency_name text DEFAULT NULL::text, p_name text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid uuid := auth.uid(); v_email text := auth.email();
  v_agent_id uuid; v_tenant_id uuid; v_slug text; v_display_name text; v_agency_name text;
  v_invite agent_invites%ROWTYPE;
BEGIN
  IF v_uid IS NULL OR v_email IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;

  SELECT id, tenant_id INTO v_agent_id, v_tenant_id FROM agent_users WHERE auth_user_id = v_uid LIMIT 1;
  IF v_agent_id IS NOT NULL THEN
    RETURN jsonb_build_object('agent_id', v_agent_id, 'tenant_id', v_tenant_id, 'is_new', false);
  END IF;

  v_display_name := coalesce(nullif(trim(p_name), ''), split_part(v_email, '@', 1));

  -- A pending invite for this email takes priority over creating a new tenant
  SELECT * INTO v_invite
  FROM agent_invites
  WHERE lower(email) = lower(v_email) AND status = 'pending' AND expires_at > now()
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_invite.id IS NOT NULL THEN
    INSERT INTO agent_users (tenant_id, auth_user_id, name, email, role)
    VALUES (v_invite.tenant_id, v_uid, v_display_name, v_email, v_invite.role)
    RETURNING id INTO v_agent_id;

    UPDATE agent_invites SET status = 'accepted', accepted_at = now() WHERE id = v_invite.id;

    RETURN jsonb_build_object('agent_id', v_agent_id, 'tenant_id', v_invite.tenant_id, 'is_new', false);
  END IF;

  v_agency_name := coalesce(nullif(trim(p_agency_name), ''), 'הסוכנות של ' || v_display_name);
  v_slug := 'agency-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12);
  INSERT INTO tenants (name, slug, plan, trial_ends_at, billing_email)
  VALUES (v_agency_name, v_slug, 'trial', now() + interval '30 days', v_email)
  RETURNING id INTO v_tenant_id;
  INSERT INTO pipeline_stages (tenant_id, name, color, order_idx, is_terminal, is_won) VALUES
    (v_tenant_id,'ליד חדש','#94A3B8',1,false,false),
    (v_tenant_id,'בקשר','#3B82F6',2,false,false),
    (v_tenant_id,'ביקור נקבע','#8B5CF6',3,false,false),
    (v_tenant_id,'הצעה הוגשה','#F59E0B',4,false,false),
    (v_tenant_id,'סגירה ✓','#10B981',5,true,true);
  INSERT INTO agent_users (tenant_id, auth_user_id, name, email, role)
  VALUES (v_tenant_id, v_uid, v_display_name, v_email, 'owner')
  RETURNING id INTO v_agent_id;
  RETURN jsonb_build_object('agent_id', v_agent_id, 'tenant_id', v_tenant_id, 'is_new', true);
END;
$$;
