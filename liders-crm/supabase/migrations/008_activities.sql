-- Liders CRM — Migration 008: Activity Log
-- Full audit trail of every interaction with a lead

CREATE TABLE IF NOT EXISTS activities (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  agent_id    uuid REFERENCES agent_users(id) ON DELETE SET NULL,
  lead_id     uuid REFERENCES leads(id) ON DELETE CASCADE,
  property_id uuid REFERENCES properties(id) ON DELETE SET NULL,
  showing_id  uuid REFERENCES showings(id) ON DELETE SET NULL,
  task_id     uuid REFERENCES tasks(id) ON DELETE SET NULL,

  type        text NOT NULL
              CHECK (type IN ('call','whatsapp','email','showing','note',
                              'stage_change','task_done','deal_closed',
                              'lead_created','ai_score','other')),
  content     text NOT NULL,
  metadata    jsonb DEFAULT '{}',   -- extra context (old_stage, new_stage, score, etc.)

  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_activities_tenant   ON activities(tenant_id);
CREATE INDEX idx_activities_lead     ON activities(lead_id, created_at DESC);
CREATE INDEX idx_activities_agent    ON activities(agent_id);
CREATE INDEX idx_activities_type     ON activities(tenant_id, type, created_at DESC);

ALTER TABLE activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant isolation" ON activities
  FOR ALL
  USING (tenant_id = get_my_tenant_id())
  WITH CHECK (tenant_id = get_my_tenant_id());

-- Auto-log when a lead's stage changes
CREATE OR REPLACE FUNCTION log_lead_stage_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.pipeline_stage_id IS DISTINCT FROM NEW.pipeline_stage_id THEN
    INSERT INTO activities (tenant_id, agent_id, lead_id, type, content, metadata)
    VALUES (
      NEW.tenant_id,
      NEW.agent_id,
      NEW.id,
      'stage_change',
      'שלב הועבר',
      jsonb_build_object('old_stage', OLD.pipeline_stage_id, 'new_stage', NEW.pipeline_stage_id)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER lead_stage_change_log
  AFTER UPDATE ON leads
  FOR EACH ROW EXECUTE FUNCTION log_lead_stage_change();
