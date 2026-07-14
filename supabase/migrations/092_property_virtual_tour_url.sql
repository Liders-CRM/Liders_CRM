-- PLTO: optional 360° virtual tour link on a property/case (e.g. Matterport/EyeSpy360/Cupix
-- hosted tour a real estate agent or interior designer got from a separate photography vendor).
-- Nullable, plain text URL — no dedicated storage/hosting, just a link the client clicks through.
alter table public.properties
  add column if not exists virtual_tour_url text;
