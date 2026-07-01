-- Migration 050: seat pricing tune-up.
-- Pro: raise max seats 7 -> 8 (still 3 included, 30 ILS/extra seat).
-- Premium: extra-seat price 30 -> 40 ILS, and cap self-serve seats at 25
-- (was a 50-seat technical ceiling with no real business limit) - beyond
-- 25 seats a real agency is a proper enterprise conversation, not a
-- self-serve linear add-on, so invite_agent() blocks and the client
-- directs them to Support instead.

CREATE OR REPLACE FUNCTION public._seat_config(p_plan text)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT (
    '{
      "trial":     {"included": 1,  "max": 1,  "price": 0},
      "basic":     {"included": 1,  "max": 1,  "price": 0},
      "pro":       {"included": 3,  "max": 8,  "price": 30},
      "premium":   {"included": 10, "max": 25, "price": 40},
      "lifetime":  {"included": 10, "max": 25, "price": 40},
      "cancelled": {"included": 0,  "max": 0,  "price": 0}
    }'::jsonb -> p_plan
  );
$$;
