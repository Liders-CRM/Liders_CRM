-- Liders CRM — Migration 003: Pipeline Stages
-- Customizable sales pipeline stages per tenant

CREATE TABLE IF NOT EXISTS pipeline_stages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name        text NOT NULL,
  color       text NOT NULL DEFAULT '#94A3B8',
  order_idx   integer NOT NULL DEFAULT 1,
  is_terminal boolean NOT NULL DEFAULT false,   -- closed_won / closed_lost
  is_won      boolean NOT NULL DEFAULT false,   -- true = closed won
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_pipeline_stages_tenant ON pipeline_stages(tenant_id, order_idx);

ALTER TABLE pipeline_stages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant isolation" ON pipeline_stages
  FOR ALL
  USING (tenant_id = get_my_tenant_id())
  WITH CHECK (tenant_id = get_my_tenant_id());
