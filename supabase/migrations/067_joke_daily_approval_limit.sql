-- Enforce: max 1 approved joke per user per calendar day.
-- Applied in admin_approve_community_joke (manual) and respected by the
-- daily Claude auto-review trigger as well.

CREATE OR REPLACE FUNCTION public.admin_approve_community_joke(
  p_pin     TEXT,
  p_joke_id UUID
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_joke  community_jokes;
  v_today INT;
BEGIN
  IF NOT (SELECT public.verify_admin_pin(p_pin)) THEN
    RETURN json_build_object('ok', false, 'reason', 'invalid_pin');
  END IF;

  SELECT * INTO v_joke FROM community_jokes WHERE id = p_joke_id;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'reason', 'not_found');
  END IF;
  IF v_joke.status <> 'pending' THEN
    RETURN json_build_object('ok', false, 'reason', 'already_processed');
  END IF;

  -- Max 1 approved joke per user per day
  SELECT COUNT(*) INTO v_today
  FROM community_jokes
  WHERE submitted_by = v_joke.submitted_by
    AND status = 'approved'
    AND approved_at >= CURRENT_DATE;

  IF v_today >= 1 THEN
    RETURN json_build_object('ok', false, 'reason', 'daily_limit_reached',
      'message', 'המשתמש כבר קיבל אישור לבדיחה אחת היום');
  END IF;

  UPDATE community_jokes
  SET status = 'approved', approved_at = now()
  WHERE id = p_joke_id;

  RETURN json_build_object('ok', true);
END;
$$;

-- Also create a service-level approve function used by the Claude auto-review trigger
-- (no PIN needed — called via service role through Supabase MCP execute_sql only)
CREATE OR REPLACE FUNCTION public.auto_approve_joke(p_joke_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_joke  community_jokes;
  v_today INT;
BEGIN
  SELECT * INTO v_joke FROM community_jokes WHERE id = p_joke_id;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'reason', 'not_found');
  END IF;
  IF v_joke.status <> 'pending' THEN
    RETURN json_build_object('ok', false, 'reason', 'already_processed');
  END IF;

  -- Max 1 approved joke per user per day
  SELECT COUNT(*) INTO v_today
  FROM community_jokes
  WHERE submitted_by = v_joke.submitted_by
    AND status = 'approved'
    AND approved_at >= CURRENT_DATE;

  IF v_today >= 1 THEN
    RETURN json_build_object('ok', false, 'reason', 'daily_limit_reached');
  END IF;

  UPDATE community_jokes
  SET status = 'approved', approved_at = now()
  WHERE id = p_joke_id;

  RETURN json_build_object('ok', true);
END;
$$;

-- auto_approve_joke is intentionally NOT granted to anon/authenticated —
-- called only via execute_sql (MCP service-level access) by the Claude trigger.
REVOKE EXECUTE ON FUNCTION public.auto_approve_joke(UUID) FROM PUBLIC, anon, authenticated;
