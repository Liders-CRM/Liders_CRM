-- PLTO: link a property to the lead it was captured from (e.g. "שמירה ממדלן" flow)
-- Nullable, optional — most properties are still added standalone with no source lead.
alter table public.properties
  add column if not exists source_lead_id uuid references public.leads(id) on delete set null;

create index if not exists idx_properties_source_lead_id
  on public.properties(source_lead_id) where source_lead_id is not null;
