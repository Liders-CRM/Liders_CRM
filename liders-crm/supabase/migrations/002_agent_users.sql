-- Liders CRM — Migration 002: Agent Users
-- Sales agents and brokers belonging to a tenant

CREATE TABLE IF NOT EXISTS agent_users (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  auth_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  name         text NOT NULL,
  email        text NOT NULL,
  phone        text,
  role         text NOT NULL DEFAULT 'agent'
               CHECK (role IN ('owner', 'admin', 'agent', 'viewer')),
  avatar_url   text,
  is_active    boolean NOT NULL DEFAULT true,
  last_login   timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, email)
);

CREATE INDEX idx_agent_users_tenant     ON agent_users(tenant_id);
CREATE INDEX idx_agent_users_auth_user  ON agent_users(auth_user_id);

ALTER TABLE agent_users ENABLE ROW LEVEL SECURITY;

-- Helper: get current user's tenant_id
CREATE OR REPLACE FUNCTION get_my_tenant_id()
RETURNS uuid AS $$
  SELECT tenant_id FROM agent_users
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Helper: get current user's agent row id
CREATE OR REPLACE FUNCTION get_my_agent_id()
RETURNS uuid AS $$
  SELECT id FROM agent_users
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- RLS: agents see and modify only their tenant's users
CREATE POLICY "agents in same tenant" ON agent_users
  FOR ALL
  USING (tenant_id = get_my_tenant_id())
  WITH CHECK (tenant_id = get_my_tenant_id());

CREATE TRIGGER agent_users_updated_at
  BEFORE UPDATE ON agent_users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
