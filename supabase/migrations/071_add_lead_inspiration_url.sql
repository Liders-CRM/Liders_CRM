-- Migration 071: Add missing inspiration_url column to leads
--
-- Pre-launch audit finding: the frontend ("לוח השראה" field, interior-design
-- vertical) has always read/written lead.inspiration_url on the in-memory JS
-- object only — the leads table never had this column, so the field silently
-- reverted on every page refresh / re-login despite the UI showing it saved.

ALTER TABLE leads ADD COLUMN IF NOT EXISTS inspiration_url text;
