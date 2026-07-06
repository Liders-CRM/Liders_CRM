-- Migration 052: block brand-new trial tenants for known disposable/
-- temp-mail email domains. Doesn't touch existing accounts or invited
-- teammates joining an existing tenant (that's not a free-trial-farming
-- vector) - only the "create a fresh 30-day trial" path is gated.

CREATE OR REPLACE FUNCTION public._is_disposable_email(p_email text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT lower(split_part(p_email, '@', 2)) = ANY (ARRAY[
    'mailinator.com','guerrillamail.com','guerrillamail.net','guerrillamail.org',
    'guerrillamail.biz','guerrillamailblock.com','sharklasers.com','grr.la',
    '10minutemail.com','10minutemail.net','10minemail.com','20minutemail.com',
    'tempmail.com','temp-mail.org','temp-mail.io','tempmail.net','tempmailo.com',
    'tempinbox.com','fakeinbox.com','fakemailgenerator.com','fakemail.net',
    'yopmail.com','yopmail.net','yopmail.fr','cool.fr.nf','jetable.fr.nf',
    'trashmail.com','trashmail.net','trashmail.me','trash-mail.com','trashmailer.com',
    'dispostable.com','maildrop.cc','mailnesia.com','mailcatch.com','mail-temporaire.fr',
    'getnada.com','nada.email','mohmal.com','emailondeck.com','moakt.com','moakt.cc',
    'inboxkitten.com','spam4.me','throwawaymail.com','mytemp.email','tempr.email',
    'discard.email','discardmail.com','mintemail.com','mvrht.net','anonbox.net',
    'burnermail.io','emailfake.com','crazymailing.com','tempmailaddress.com',
    'mail-temp.com','one-time.email','harakirimail.com','shieldedmail.com',
    'spamgourmet.com','spambox.us','tmpmail.org','tmpeml.com','tmail.ws'
  ]);
$$;

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

  IF public._is_disposable_email(v_email) THEN
    RAISE EXCEPTION 'disposable_email_blocked';
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
