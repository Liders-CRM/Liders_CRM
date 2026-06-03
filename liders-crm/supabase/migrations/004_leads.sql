-- Liders CRM — Migration 004: Leads (Contacts)
-- The core entity: potential buyers, sellers, or clients

CREATE TABLE IF NOT EXISTS leads (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  agent_id         uuid REFERENCES agent_users(id) ON DELETE SET NULL,
  pipeline_stage_id uuid REFERENCES pipeline_stages(id) ON DELETE SET NULL,

  -- Contact info
  name             text NOT NULL,
  phone            text NOT NULL,
  email            text,

  -- Classification
  source           text NOT NULL DEFAULT 'other'
                   CHECK (source IN ('yad2','madlan','facebook','instagram','referral',
                                     'website','call','whatsapp','email','ad','other')),
  status           text NOT NULL DEFAULT 'new'
                   CHECK (status IN ('new','contacted','qualified','showing',
                                     'offer','closed_won','closed_lost','frozen')),

  -- Real-estate specific
  budget_min       numeric(14,2),
  budget_max       numeric(14,2),
  desired_area     text,
  rooms_min        numeric(3,1),
  rooms_max        numeric(3,1),
  property_type    text,            -- apartment, house, etc.
  urgency          text DEFAULT 'medium'
                   CHECK (urgency IN ('low','medium','high','immediate')),

  -- AI & tracking
  score            integer NOT NULL DEFAULT 50 CHECK (score BETWEEN 0 AND 100),
  score_reason     text,
  last_contact     timestamptz,
  next_followup    timestamptz,
  followup_count   integer NOT NULL DEFAULT 0,

  notes            text DEFAULT '',
  tags             text[] DEFAULT '{}',

  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_leads_tenant          ON leads(tenant_id);
CREATE INDEX idx_leads_agent           ON leads(agent_id);
CREATE INDEX idx_leads_stage           ON leads(pipeline_stage_id);
CREATE INDEX idx_leads_status          ON leads(tenant_id, status);
CREATE INDEX idx_leads_next_followup   ON leads(tenant_id, next_followup) WHERE status NOT IN ('closed_won','closed_lost');

ALTER TABLE leads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant isolation" ON leads
  FOR ALL
  USING (tenant_id = get_my_tenant_id())
  WITH CHECK (tenant_id = get_my_tenant_id());

CREATE TRIGGER leads_updated_at
  BEFORE UPDATE ON leads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
