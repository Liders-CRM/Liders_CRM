-- Migration 062: unify extra-seat price at 40 ILS for every plan.
-- Decision 3/7/2026: the landing page advertises 40 ILS/extra agent on both
-- Pro and Premium; the SQL still charged 30 ILS on Pro (see migration 050).
-- Single source of truth stays here in _seat_config.

CREATE OR REPLACE FUNCTION public._seat_config(p_plan text)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT (
    '{
      "trial":     {"included": 1,  "max": 1,  "price": 0},
      "basic":     {"included": 1,  "max": 1,  "price": 0},
      "pro":       {"included": 3,  "max": 8,  "price": 40},
      "premium":   {"included": 10, "max": 25, "price": 40},
      "lifetime":  {"included": 10, "max": 25, "price": 40},
      "cancelled": {"included": 0,  "max": 0,  "price": 0}
    }'::jsonb -> p_plan
  );
$$;
