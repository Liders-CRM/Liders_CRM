-- Liders CRM — Migration 001: Tenants
-- Multi-tenant SaaS: each business gets an isolated tenant

CREATE TABLE IF NOT EXISTS tenants (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,
  slug            text UNIQUE NOT NULL,
  logo_url        text,
  primary_color   text DEFAULT '#1C3E6B',
  phone           text,
  whatsapp_number text,
  make_webhook_url text,
  plan            text NOT NULL DEFAULT 'trial'
                  CHECK (plan IN ('trial', 'basic', 'pro', 'enterprise')),
  plan_expires_at timestamptz,
  industry        text DEFAULT 'real_estate'
                  CHECK (industry IN ('real_estate', 'sales', 'marketing', 'other')),
  city            text,
  country         text DEFAULT 'IL',
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;

-- Service role can read/write all tenants (for admin operations)
CREATE POLICY "service role full access" ON tenants
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Authenticated users can only read their own tenant
-- (joined via agent_users — enforced in app layer)
CREATE POLICY "anon no access" ON tenants
  FOR ALL
  TO anon
  USING (false);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tenants_updated_at
  BEFORE UPDATE ON tenants
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
