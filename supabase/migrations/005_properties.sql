-- Liders CRM — Migration 005: Properties (Listings)
-- Real estate listings managed by the agency

CREATE TABLE IF NOT EXISTS properties (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  agent_id     uuid REFERENCES agent_users(id) ON DELETE SET NULL,

  title        text NOT NULL,
  type         text NOT NULL DEFAULT 'apartment'
               CHECK (type IN ('apartment','house','penthouse','villa',
                               'commercial','office','land','other')),
  status       text NOT NULL DEFAULT 'available'
               CHECK (status IN ('available','under_offer','sold','rented',
                                 'off_market','coming_soon')),

  -- Pricing
  price        numeric(14,2) NOT NULL,
  price_negotiable boolean DEFAULT true,

  -- Physical
  area_sqm     numeric(8,2),
  rooms        numeric(3,1),
  bathrooms    integer,
  floor        integer,
  total_floors integer,
  parking      integer DEFAULT 0,
  storage      boolean DEFAULT false,

  -- Location
  address      text NOT NULL,
  city         text NOT NULL,
  neighborhood text,
  zip_code     text,
  lat          numeric(10,7),
  lng          numeric(10,7),

  -- Details
  description  text DEFAULT '',
  amenities    text[] DEFAULT '{}',
  photos       text[] DEFAULT '{}',      -- Supabase storage URLs
  virtual_tour_url text,
  yad2_url     text,
  madlan_url   text,

  -- Dates
  listed_at    date DEFAULT CURRENT_DATE,
  sold_at      date,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_properties_tenant   ON properties(tenant_id);
CREATE INDEX idx_properties_status   ON properties(tenant_id, status);
CREATE INDEX idx_properties_city     ON properties(tenant_id, city);
CREATE INDEX idx_properties_price    ON properties(tenant_id, price);

ALTER TABLE properties ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant isolation" ON properties
  FOR ALL
  USING (tenant_id = get_my_tenant_id())
  WITH CHECK (tenant_id = get_my_tenant_id());

CREATE TRIGGER properties_updated_at
  BEFORE UPDATE ON properties
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
