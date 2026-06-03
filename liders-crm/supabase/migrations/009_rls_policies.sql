-- Liders CRM — Migration 009: Consolidated RLS + Security Hardening
-- Run after all other migrations

-- ─────────────────────────────────────────────
-- AUDIT LOG (no tenant isolation — append only)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid,
  agent_id    uuid,
  action      text NOT NULL,
  entity_type text,
  entity_id   uuid,
  old_value   jsonb,
  new_value   jsonb,
  ip_address  inet,
  user_agent  text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Only service role can read audit_log
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service role only" ON audit_log
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────────
-- REVOKE public schema access (security best practice)
-- ─────────────────────────────────────────────
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;

-- Grant authenticated users access to their own data via RLS
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ─────────────────────────────────────────────
-- LEAD SCORE MATERIALIZED VIEW (for quick analytics)
-- ─────────────────────────────────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS lead_score_summary AS
SELECT
  tenant_id,
  COUNT(*) FILTER (WHERE score >= 80) AS hot_leads,
  COUNT(*) FILTER (WHERE score BETWEEN 60 AND 79) AS warm_leads,
  COUNT(*) FILTER (WHERE score BETWEEN 40 AND 59) AS cool_leads,
  COUNT(*) FILTER (WHERE score < 40) AS cold_leads,
  AVG(score)::numeric(5,1) AS avg_score,
  COUNT(*) FILTER (WHERE status NOT IN ('closed_won','closed_lost')) AS active_leads,
  COUNT(*) FILTER (WHERE status = 'closed_won') AS won_deals,
  SUM(budget_max) FILTER (WHERE status NOT IN ('closed_won','closed_lost')) AS pipeline_value
FROM leads
GROUP BY tenant_id;

-- ─────────────────────────────────────────────
-- OVERDUE TASKS VIEW (for dashboard/notifications)
-- ─────────────────────────────────────────────
CREATE OR REPLACE VIEW overdue_tasks AS
SELECT
  t.*,
  l.name AS lead_name,
  l.phone AS lead_phone,
  au.name AS agent_name
FROM tasks t
LEFT JOIN leads l ON l.id = t.lead_id
LEFT JOIN agent_users au ON au.id = t.agent_id
WHERE t.done = false
  AND t.due_date < now();

-- ─────────────────────────────────────────────
-- PIPELINE SUMMARY VIEW (for analytics dashboard)
-- ─────────────────────────────────────────────
CREATE OR REPLACE VIEW pipeline_summary AS
SELECT
  l.tenant_id,
  ps.id AS stage_id,
  ps.name AS stage_name,
  ps.color,
  ps.order_idx,
  COUNT(l.id) AS lead_count,
  COALESCE(SUM(l.budget_max), 0) AS total_value,
  AVG(l.score)::numeric(5,1) AS avg_score
FROM pipeline_stages ps
LEFT JOIN leads l ON l.pipeline_stage_id = ps.id
  AND l.status NOT IN ('closed_won','closed_lost')
GROUP BY l.tenant_id, ps.id, ps.name, ps.color, ps.order_idx
ORDER BY ps.order_idx;
