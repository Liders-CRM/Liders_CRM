-- Migration 096: lower the team (pro) plan self-serve seat cap from 8 to 7.
--
-- At 8 seats a team-plan tenant already pays the exact same monthly total
-- (349 + 5*40 = 549) as the agency (premium) plan's base price for 10
-- included seats, so the 8th seat was strictly worse value than upgrading.
-- Capping team at 7 (349 + 4*40 = 509) keeps team always cheaper than
-- agency's base, and pushes the same customer into the agency plan at the
-- exact same price point they'd already hit, but with more headroom
-- (10 included, room to grow to 25) instead of being capped at 8.
--
-- Decision made with the user 18/7/2026. No live tenant is currently at
-- 8 seats, so this is safe to apply with no grandfathering needed.

CREATE OR REPLACE FUNCTION public._seat_config(p_plan text)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT (
    '{
      "trial":     {"included": 1,  "max": 1,  "price": 0},
      "basic":     {"included": 1,  "max": 1,  "price": 0},
      "pro":       {"included": 3,  "max": 7,  "price": 40},
      "premium":   {"included": 10, "max": 25, "price": 40},
      "lifetime":  {"included": 10, "max": 25, "price": 40},
      "cancelled": {"included": 0,  "max": 0,  "price": 0}
    }'::jsonb -> p_plan
  );
$$;
