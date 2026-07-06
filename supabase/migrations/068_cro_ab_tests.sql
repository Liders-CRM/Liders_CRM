-- Migration 068: cro_ab_tests table + admin RPCs
-- טבלת A/B tests לניהול ניסויים מהאדמין.

CREATE TABLE IF NOT EXISTS public.cro_ab_tests (
  id           UUID         DEFAULT gen_random_uuid() PRIMARY KEY,
  name         TEXT         NOT NULL,
  hypothesis   TEXT,
  variant_a    TEXT,
  variant_b    TEXT,
  status       TEXT         DEFAULT 'backlog' CHECK (status IN ('backlog','active','concluded')),
  winner       TEXT                           CHECK (winner IN ('a','b') OR winner IS NULL),
  started_at   TIMESTAMPTZ,
  ended_at     TIMESTAMPTZ,
  created_at   TIMESTAMPTZ  DEFAULT now()
);

ALTER TABLE public.cro_ab_tests ENABLE ROW LEVEL SECURITY;
-- קריאה/כתיבה רק דרך SECURITY DEFINER RPCs — ללא גישה ישירה

-- ── RPC: admin_list_ab_tests ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_list_ab_tests()
RETURNS TABLE (
  id UUID, name TEXT, hypothesis TEXT,
  variant_a TEXT, variant_b TEXT,
  status TEXT, winner TEXT,
  started_at TIMESTAMPTZ, ended_at TIMESTAMPTZ, created_at TIMESTAMPTZ,
  exposures_a BIGINT, exposures_b BIGINT,
  conversions_a BIGINT, conversions_b BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF current_role NOT IN ('postgres', 'service_role') THEN
    RAISE EXCEPTION 'admin only';
  END IF;
  RETURN QUERY
  SELECT
    t.id, t.name, t.hypothesis,
    t.variant_a, t.variant_b,
    t.status, t.winner,
    t.started_at, t.ended_at, t.created_at,
    (SELECT count(*) FROM funnel_events e WHERE e.event_name='ab_exposure'   AND e.event_data->>'test_id'=t.id::text AND e.event_data->>'variant'='a'),
    (SELECT count(*) FROM funnel_events e WHERE e.event_name='ab_exposure'   AND e.event_data->>'test_id'=t.id::text AND e.event_data->>'variant'='b'),
    (SELECT count(*) FROM funnel_events e WHERE e.event_name='ab_converted'  AND e.event_data->>'test_id'=t.id::text AND e.event_data->>'variant'='a'),
    (SELECT count(*) FROM funnel_events e WHERE e.event_name='ab_converted'  AND e.event_data->>'test_id'=t.id::text AND e.event_data->>'variant'='b')
  FROM cro_ab_tests t
  ORDER BY
    CASE t.status WHEN 'active' THEN 0 WHEN 'backlog' THEN 1 ELSE 2 END,
    t.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_ab_tests() TO postgres;
GRANT EXECUTE ON FUNCTION public.admin_list_ab_tests() TO service_role;

-- ── RPC: admin_upsert_ab_test ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_upsert_ab_test(
  p_id         UUID,
  p_name       TEXT,
  p_hypothesis TEXT,
  p_variant_a  TEXT,
  p_variant_b  TEXT,
  p_status     TEXT,
  p_winner     TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  IF current_role NOT IN ('postgres', 'service_role') THEN
    RAISE EXCEPTION 'admin only';
  END IF;
  IF p_id IS NOT NULL THEN
    UPDATE cro_ab_tests SET
      name       = COALESCE(p_name, name),
      hypothesis = COALESCE(p_hypothesis, hypothesis),
      variant_a  = COALESCE(p_variant_a, variant_a),
      variant_b  = COALESCE(p_variant_b, variant_b),
      status     = COALESCE(p_status, status),
      winner     = p_winner,
      started_at = CASE WHEN p_status='active'    AND started_at IS NULL THEN now() ELSE started_at END,
      ended_at   = CASE WHEN p_status='concluded' AND ended_at   IS NULL THEN now() ELSE ended_at   END
    WHERE id = p_id
    RETURNING id INTO v_id;
  ELSE
    INSERT INTO cro_ab_tests (name, hypothesis, variant_a, variant_b, status, winner)
    VALUES (p_name, p_hypothesis, p_variant_a, p_variant_b, COALESCE(p_status,'backlog'), p_winner)
    RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_upsert_ab_test(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) TO postgres;
GRANT EXECUTE ON FUNCTION public.admin_upsert_ab_test(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) TO service_role;

-- ── RPC: get_active_ab_tests (public, for the frontend A/B engine) ──────────
CREATE OR REPLACE FUNCTION public.get_active_ab_tests()
RETURNS TABLE (id UUID, name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT t.id, t.name FROM cro_ab_tests t WHERE t.status = 'active';
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_active_ab_tests() TO anon;
GRANT EXECUTE ON FUNCTION public.get_active_ab_tests() TO authenticated;
