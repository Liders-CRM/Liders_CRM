-- Migration 055: buyer/seller role on leads.
-- Real estate agents represent both sides of a deal; leads were implicitly
-- treated as "buyers" only (hardcoded terminology in the client). Adds an
-- explicit role so agents can tag, badge, and filter their pipeline by it.

ALTER TABLE leads ADD COLUMN IF NOT EXISTS lead_role text NOT NULL DEFAULT 'buyer'
  CHECK (lead_role IN ('buyer','seller','both'));
