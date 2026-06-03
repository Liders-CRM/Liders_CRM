-- Liders CRM — Migration 007: Showings (Property Visits)
-- Track when a lead views a property

CREATE TABLE IF NOT EXISTS showings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  agent_id        uuid REFERENCES agent_users(id) ON DELETE SET NULL,
  lead_id         uuid NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  property_id     uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,

  scheduled_at    timestamptz NOT NULL,
  duration_min    integer DEFAULT 30,
  status          text NOT NULL DEFAULT 'scheduled'
                  CHECK (status IN ('scheduled','completed','cancelled','no_show','rescheduled')),

  -- Post-visit feedback
  feedback        text,
  interest_level  integer CHECK (interest_level BETWEEN 1 AND 5),
  next_action     text,

  google_event_id text,   -- Google Calendar event ID for sync
  notes           text DEFAULT '',

  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_showings_tenant   ON showings(tenant_id);
CREATE INDEX idx_showings_lead     ON showings(lead_id);
CREATE INDEX idx_showings_property ON showings(property_id);
CREATE INDEX idx_showings_date     ON showings(tenant_id, scheduled_at);

ALTER TABLE showings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant isolation" ON showings
  FOR ALL
  USING (tenant_id = get_my_tenant_id())
  WITH CHECK (tenant_id = get_my_tenant_id());

CREATE TRIGGER showings_updated_at
  BEFORE UPDATE ON showings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
