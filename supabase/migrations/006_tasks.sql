-- Liders CRM — Migration 006: Tasks & Reminders

CREATE TABLE IF NOT EXISTS tasks (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  agent_id     uuid REFERENCES agent_users(id) ON DELETE SET NULL,
  lead_id      uuid REFERENCES leads(id) ON DELETE CASCADE,
  property_id  uuid REFERENCES properties(id) ON DELETE SET NULL,

  title        text NOT NULL,
  type         text NOT NULL DEFAULT 'other'
               CHECK (type IN ('call','whatsapp','email','showing',
                               'offer','meeting','document','other')),
  priority     text NOT NULL DEFAULT 'medium'
               CHECK (priority IN ('low','medium','high','urgent')),

  due_date     timestamptz,
  done         boolean NOT NULL DEFAULT false,
  done_at      timestamptz,

  notes        text DEFAULT '',
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_tasks_tenant      ON tasks(tenant_id);
CREATE INDEX idx_tasks_agent       ON tasks(agent_id);
CREATE INDEX idx_tasks_lead        ON tasks(lead_id);
CREATE INDEX idx_tasks_due         ON tasks(tenant_id, due_date) WHERE done = false;
CREATE INDEX idx_tasks_overdue     ON tasks(tenant_id, due_date)
  WHERE done = false AND due_date < now();

ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant isolation" ON tasks
  FOR ALL
  USING (tenant_id = get_my_tenant_id())
  WITH CHECK (tenant_id = get_my_tenant_id());

CREATE TRIGGER tasks_updated_at
  BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
