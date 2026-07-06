-- Migration 065: add renter/landlord to lead_role
-- Real estate agents handle rentals too; the original buyer/seller/both
-- values covered only purchase transactions. Extends the enum-like check
-- so agents can tag leads as renters (🔑) or landlords (🏘) and filter them.

ALTER TABLE leads DROP CONSTRAINT IF EXISTS leads_lead_role_check;

ALTER TABLE leads ADD CONSTRAINT leads_lead_role_check
  CHECK (lead_role IN ('buyer','seller','both','renter','landlord'));
