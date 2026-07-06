-- Migration 060: fix tenants.industry CHECK constraint to match the 3 verticals
-- actually supported by the app (index.html INDUSTRY_LABELS: realestate,
-- realestate_lawyer, interior, other). The live constraint had drifted to an
-- unrelated set of values (interior_design, realestate_law, mortgages,
-- property_insurance, staging_photo, realestate_tax, real_estate, sales,
-- marketing) that never matched the frontend's industry ids, so every
-- onboarding write silently stuck at the DEFAULT 'real_estate' value.
-- No real tenants exist yet (pre-launch), so pre-launch test rows are reset
-- to 'other' rather than migrated value-by-value.

alter table public.tenants drop constraint if exists tenants_industry_check;

update public.tenants set industry = 'other'
where industry not in ('realestate', 'realestate_lawyer', 'interior');

alter table public.tenants
  alter column industry set default 'other',
  add constraint tenants_industry_check
    check (industry in ('realestate', 'realestate_lawyer', 'interior', 'other'));
